import { access } from 'node:fs/promises';
import { join } from 'node:path';
import type { Writable } from 'node:stream';

import type { db } from '@via/db';
import {
  transitProfileStops,
  transitRoutePatternStops,
  transitServiceDates,
  transitStopRoutes,
  transitStops,
  transitTimeProfiles,
  transitTrips,
} from '@via/db/schema';
import { sql } from 'drizzle-orm';

import type { PositionalCsv } from '../csv';
import { formatCount, logStep } from '../progress';
import {
  expandServiceDates,
  type CalendarDateRow,
  type CalendarRow,
} from './expand-service-dates';
import { buildTimeProfiles, STOP_TIME_COLUMNS, type StopTimeColumn } from './time-profiles';

type Transaction = Parameters<Parameters<typeof db.transaction>[0]>[0];

type CopyClient = {
  (strings: TemplateStringsArray, ...values: readonly unknown[]): {
    writable: () => Promise<Writable>;
  };
};

type TransactionWithClient = Transaction & {
  session: { client: CopyClient };
};

export type ScheduledTrip = {
  numericId: number;
  id: string;
  routeId: string;
  directionId: number;
  headsign: string;
  serviceId: string;
  shapeId: string;
};

type ImportSchedulesOptions = {
  gtfsPath: string;
  tx: Transaction;
  /** Every trip of the imported network, keyed by trip id — not just representatives. */
  trips: Map<string, ScheduledTrip>;
  canonicalStopIdOf: (stopId: string) => string;
  /** Dense key of every canonical stop imported from the feed. */
  stopKeyById: ReadonlyMap<string, number>;
  /** One representative trip per editorial map pattern. */
  representativeTrips: ReadonlyMap<string, number>;
  readCsv: (path: string) => AsyncGenerator<Record<string, string>>;
  readPositionalCsv: <Column extends string>(
    path: string,
    columns: readonly Column[]
  ) => Promise<PositionalCsv<Column>>;
};

// Keep every statement under Postgres' 65k parameter limit while reducing
// round-trips for the full feed. A trip row has nine parameters, so 7k stays
// safe; two-parameter rows get more headroom.
const TRIP_INSERT_BATCH = 7_000;
const INSERT_BATCH = 8_000;

/**
 * The theoretical half of the import: streams `stop_times.txt` once, collapses
 * every trip into a deduplicated time profile (see `buildTimeProfiles`), and
 * expands the calendar files into explicit service days. It shares the network
 * transaction so a crash cannot expose a half-written fallback.
 */
export async function importSchedules({
  gtfsPath,
  tx,
  trips,
  canonicalStopIdOf,
  stopKeyById,
  representativeTrips,
  readCsv,
  readPositionalCsv,
}: ImportSchedulesOptions) {
  logStep('Streaming stop_times.txt into time profiles');
  const profiles = await buildTimeProfiles({
    stopTimes: await readPositionalCsv<StopTimeColumn>(
      join(gtfsPath, 'stop_times.txt'),
      STOP_TIME_COLUMNS
    ),
    trips,
    canonicalStopIdOf,
    stopKeyById,
  });

  // Profiles must exist before the COPY below and the trips insert satisfy
  // their foreign keys; ids are dense 1..N by construction.
  if (profiles.profileCount > 0) {
    await tx.execute(
      sql`INSERT INTO ${transitTimeProfiles} (id) SELECT generate_series(1, ${profiles.profileCount}::integer)`
    );
  }

  const copyClient = (tx as TransactionWithClient).session.client;
  const copyWriter = await copyClient`
    COPY transit_profile_stops
      (profile_key, position, stop_key, arrival_offset, departure_offset)
    FROM STDIN WITH (FORMAT text, DELIMITER E'\\t')
  `.writable();
  await profiles.writeProfileStopsTo(copyWriter);
  logStep(
    `Copied ${formatCount(profiles.callCount)} calls of ` +
      `${formatCount(profiles.profileCount)} time profiles.`
  );

  /**
   * Built one batch at a time rather than as one array of every trip: the feed
   * has ~700k of them, and materializing a second full copy of the map next to
   * the map itself was a needless multi-hundred-megabyte spike right at the
   * point of the import where memory is already at its worst.
   *
   * A trip whose every call was skipped has no profile to reference, so it is
   * dropped here rather than violating the foreign key.
   */
  logStep('Inserting trips');
  let importedTripCount = 0;
  let tripBatch: (typeof transitTrips.$inferInsert)[] = [];
  const flushTripBatch = async () => {
    if (tripBatch.length === 0) return;
    await tx.insert(transitTrips).values(tripBatch);
    tripBatch = [];
  };
  for (const trip of trips.values()) {
    const assignment = profiles.assignmentForTrip(trip.numericId);
    if (!assignment) continue;
    importedTripCount += 1;
    tripBatch.push({
      numericId: trip.numericId,
      id: trip.id,
      routeId: trip.routeId,
      serviceId: trip.serviceId,
      directionId: trip.directionId,
      headsign: trip.headsign,
      shapeId: trip.shapeId,
      profileKey: assignment.profileKey,
      startSeconds: assignment.startSeconds,
    });
    if (tripBatch.length === TRIP_INSERT_BATCH) await flushTripBatch();
  }
  await flushTripBatch();
  logStep(`Inserted ${formatCount(importedTripCount)} trips; deriving route patterns…`);

  /**
   * Derive map calls from each pattern's representative profile in SQL.
   * Consecutive platform aliases were canonicalized before profiles were
   * built, so the window query can collapse them cheaply. The stored
   * stop_sequence is the profile's dense position, which only has to order
   * the calls — no consumer expects raw GTFS sequence values.
   */
  const patternValues = [...representativeTrips].flatMap(([patternId, tripKey]) => {
    const assignment = profiles.assignmentForTrip(tripKey);
    return assignment ? [sql`(${patternId}, ${assignment.profileKey}::integer)`] : [];
  });
  if (patternValues.length > 0) {
    await tx.execute(sql`
      INSERT INTO ${transitRoutePatternStops} (pattern_id, stop_id, stop_sequence)
      SELECT collapsed.pattern_id, collapsed.stop_id, collapsed.position
      FROM (
        SELECT representatives.pattern_id,
               stops.id AS stop_id,
               calls.position,
               lag(stops.id) OVER (
                 PARTITION BY representatives.pattern_id ORDER BY calls.position
               ) AS previous_stop_id
        FROM (VALUES ${sql.join(patternValues, sql`, `)}) AS representatives(pattern_id, profile_key)
        INNER JOIN ${transitProfileStops} AS calls
          ON calls.profile_key = representatives.profile_key
        INNER JOIN ${transitStops} AS stops
          ON stops.numeric_id = calls.stop_key
      ) AS collapsed
      WHERE collapsed.previous_stop_id IS NULL
         OR collapsed.previous_stop_id <> collapsed.stop_id
      ON CONFLICT DO NOTHING
    `);
  }

  const stopRoutes = [...profiles.stopRoutePairs.values()];
  for (let start = 0; start < stopRoutes.length; start += INSERT_BATCH) {
    await tx
      .insert(transitStopRoutes)
      .values(stopRoutes.slice(start, start + INSERT_BATCH))
      .onConflictDoNothing();
  }

  logStep('Expanding service days');
  const serviceIds = new Set<string>();
  for (const trip of trips.values()) serviceIds.add(trip.serviceId);
  // Past days are dead weight: the planner only ever asks for today onwards.
  const today = new Date().toISOString().slice(0, 10);
  const serviceDates = expandServiceDates(
    await readGtfsRows(join(gtfsPath, 'calendar.txt'), serviceIds, readCsv, toCalendarRow),
    await readGtfsRows(
      join(gtfsPath, 'calendar_dates.txt'),
      serviceIds,
      readCsv,
      toCalendarDateRow
    )
  ).filter((serviceDate) => serviceDate.date >= today);

  for (let start = 0; start < serviceDates.length; start += INSERT_BATCH) {
    await tx
      .insert(transitServiceDates)
      .values(serviceDates.slice(start, start + INSERT_BATCH))
      .onConflictDoNothing();
  }

  /** Another mode's re-import may have orphaned its days; sweep them here. */
  await tx.execute(sql`
    DELETE FROM ${transitServiceDates} AS dates
    WHERE NOT EXISTS (
      SELECT 1 FROM ${transitTrips} AS trips
      WHERE trips.service_id = dates.service_id
    )
  `);

  const droppedTrips = trips.size - importedTripCount;
  logStep(
    `Imported ${formatCount(profiles.stats.departureCount)} calls as ` +
      `${formatCount(profiles.profileCount)} time profiles ` +
      `over ${formatCount(serviceDates.length)} service days` +
      (droppedTrips > 0 ? ` (${droppedTrips} trips without usable calls dropped)` : '') +
      (profiles.stats.skippedStops > 0
        ? ` (${profiles.stats.skippedStops} calls on unknown stops skipped).`
        : '.')
  );
}

async function exists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

/**
 * Streams a GTFS calendar file down to the rows of the imported services.
 * GTFS allows a feed to express its calendar entirely through
 * calendar_dates.txt (and vice versa) — a missing file is an empty one.
 */
async function readGtfsRows<Row>(
  path: string,
  serviceIds: Set<string>,
  readCsv: ImportSchedulesOptions['readCsv'],
  toRow: (row: Record<string, string>) => Row
): Promise<Row[]> {
  const rows: Row[] = [];
  if (!(await exists(path))) return rows;
  for await (const row of readCsv(path)) {
    if (serviceIds.has(row.service_id)) rows.push(toRow(row));
  }
  return rows;
}

function toCalendarRow(row: Record<string, string>): CalendarRow {
  return {
    serviceId: row.service_id,
    weekdays: [
      row.monday === '1',
      row.tuesday === '1',
      row.wednesday === '1',
      row.thursday === '1',
      row.friday === '1',
      row.saturday === '1',
      row.sunday === '1',
    ],
    startDate: row.start_date,
    endDate: row.end_date,
  };
}

function toCalendarDateRow(row: Record<string, string>): CalendarDateRow {
  return {
    serviceId: row.service_id,
    date: row.date,
    exceptionType: Number(row.exception_type),
  };
}

import { access } from 'node:fs/promises';
import { join } from 'node:path';
import { Readable, type Writable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

import type { db } from '@via/db';
import {
  transitRoutePatternStops,
  transitServiceDates,
  transitStopRoutes,
  transitStops,
  transitTripStopTimes,
  transitTrips,
} from '@via/db/schema';
import { sql } from 'drizzle-orm';

import {
  expandServiceDates,
  type CalendarDateRow,
  type CalendarRow,
} from './expand-service-dates';
import { parseGtfsTime } from './gtfs-time';

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
};

// Keep every statement under Postgres' 65k parameter limit while reducing
// round-trips for the full feed. A stop-time row has five parameters; a trip
// row has seven, so 8k is safe for both.
const INSERT_BATCH = 8_000;

/**
 * The theoretical half of the import: streams `stop_times.txt` once into the
 * compact normalized timetable and expands the calendar files into explicit
 * service days. It shares the network transaction so a crash cannot expose a
 * half-written fallback.
 */
export async function importSchedules({
  gtfsPath,
  tx,
  trips,
  canonicalStopIdOf,
  stopKeyById,
  representativeTrips,
  readCsv,
}: ImportSchedulesOptions) {
  const tripRows = [...trips.values()].map((trip) => ({
    numericId: trip.numericId,
    id: trip.id,
    routeId: trip.routeId,
    serviceId: trip.serviceId,
    directionId: trip.directionId,
    headsign: trip.headsign,
    shapeId: trip.shapeId,
  }));
  for (let start = 0; start < tripRows.length; start += INSERT_BATCH) {
    await tx.insert(transitTrips).values(tripRows.slice(start, start + INSERT_BATCH));
  }

  const stopRoutePairs = new Map<string, { stopId: string; routeId: string }>();
  const counters = { departureCount: 0, skippedStops: 0 };
  const stopTimeRows = streamStopTimes({
    gtfsPath,
    trips,
    canonicalStopIdOf,
    stopKeyById,
    stopRoutePairs,
    counters,
    readCsv,
  });
  const copyClient = (tx as TransactionWithClient).session.client;
  const copyWriter = await copyClient`
    COPY transit_trip_stop_times
      (trip_key, stop_key, stop_sequence, arrival_seconds, departure_seconds)
    FROM STDIN WITH (FORMAT text, DELIMITER E'\\t', NULL '\\N')
  `.writable();
  await pipeline(Readable.from(stopTimeRows), copyWriter);
  console.log(`Copied ${counters.departureCount} stop-times; deriving route patterns…`);

  /**
   * Derive map calls from the normalized stream in SQL. This avoids a second
   * full `stop_times.txt` pass and avoids duplicating every call in the legacy
   * flat departure table. Consecutive platform aliases were canonicalized
   * before insertion, so the window query can collapse them cheaply.
   */
  const patternValues = [...representativeTrips].map(
    ([patternId, tripKey]) => sql`(${patternId}, ${tripKey}::integer)`
  );
  if (patternValues.length > 0) {
    await tx.execute(sql`
      INSERT INTO ${transitRoutePatternStops} (pattern_id, stop_id, stop_sequence)
      SELECT collapsed.pattern_id, collapsed.stop_id, collapsed.stop_sequence
      FROM (
        SELECT representatives.pattern_id,
               stops.id AS stop_id,
               calls.stop_sequence,
               lag(stops.id) OVER (
                 PARTITION BY calls.trip_key ORDER BY calls.stop_sequence
               ) AS previous_stop_id
        FROM (VALUES ${sql.join(patternValues, sql`, `)}) AS representatives(pattern_id, trip_key)
        INNER JOIN ${transitTripStopTimes} AS calls
          ON calls.trip_key = representatives.trip_key
        INNER JOIN ${transitStops} AS stops
          ON stops.numeric_id = calls.stop_key
      ) AS collapsed
      WHERE collapsed.previous_stop_id IS NULL
         OR collapsed.previous_stop_id <> collapsed.stop_id
      ON CONFLICT DO NOTHING
    `);
  }

  const stopRoutes = [...stopRoutePairs.values()];
  for (let start = 0; start < stopRoutes.length; start += INSERT_BATCH) {
    await tx
      .insert(transitStopRoutes)
      .values(stopRoutes.slice(start, start + INSERT_BATCH))
      .onConflictDoNothing();
  }

  const serviceIds = new Set([...trips.values()].map((trip) => trip.serviceId));
  const serviceDates = expandServiceDates(
    await readGtfsRows(join(gtfsPath, 'calendar.txt'), serviceIds, readCsv, toCalendarRow),
    await readGtfsRows(
      join(gtfsPath, 'calendar_dates.txt'),
      serviceIds,
      readCsv,
      toCalendarDateRow
    )
  );

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

  // The next request must get production query plans immediately after the
  // atomic swap; waiting for autovacuum would make a fresh import look broken.
  await tx.execute(sql`ANALYZE ${transitTrips}`);
  await tx.execute(sql`ANALYZE ${transitTripStopTimes}`);
  await tx.execute(sql`ANALYZE ${transitServiceDates}`);

  console.log(
    `Imported ${counters.departureCount} normalized stop-times over ${serviceDates.length} service days` +
      (counters.skippedStops > 0 ? ` (${counters.skippedStops} calls on unknown stops skipped).` : '.')
  );
}

type StopTimeStreamOptions = {
  gtfsPath: string;
  trips: Map<string, ScheduledTrip>;
  canonicalStopIdOf: (stopId: string) => string;
  stopKeyById: ReadonlyMap<string, number>;
  stopRoutePairs: Map<string, { stopId: string; routeId: string }>;
  counters: { departureCount: number; skippedStops: number };
  readCsv: ImportSchedulesOptions['readCsv'];
};

/**
 * Convert GTFS rows directly to PostgreSQL COPY text. COPY keeps one database
 * round-trip for the complete 14.8 M-row feed while the generator preserves
 * backpressure, so the worker never builds the timetable in memory.
 */
async function* streamStopTimes({
  gtfsPath,
  trips,
  canonicalStopIdOf,
  stopKeyById,
  stopRoutePairs,
  counters,
  readCsv,
}: StopTimeStreamOptions) {
  for await (const stopTime of readCsv(join(gtfsPath, 'stop_times.txt'))) {
    const trip = trips.get(stopTime.trip_id);
    if (!trip || (!stopTime.departure_time && !stopTime.arrival_time)) continue;

    const stopId = canonicalStopIdOf(stopTime.stop_id);
    const stopKey = stopKeyById.get(stopId);
    if (stopKey === undefined) {
      counters.skippedStops += 1;
      continue;
    }

    const arrivalSeconds = parseGtfsTime(stopTime.arrival_time || stopTime.departure_time);
    const departureSeconds = parseGtfsTime(stopTime.departure_time || stopTime.arrival_time);
    stopRoutePairs.set(`${stopId}\u0000${trip.routeId}`, { stopId, routeId: trip.routeId });
    counters.departureCount += 1;
    if (counters.departureCount % 1_000_000 === 0) {
      console.log(`Streamed ${counters.departureCount} stop-times…`);
    }
    yield [trip.numericId, stopKey, Number(stopTime.stop_sequence), arrivalSeconds, departureSeconds]
      .map(copyTextCell)
      .join('\t') + '\n';
  }
}

function copyTextCell(value: string | number) {
  return String(value)
    .replaceAll('\\', '\\\\')
    .replaceAll('\t', '\\t')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\r');
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

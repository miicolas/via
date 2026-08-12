import { access } from 'node:fs/promises';
import { join } from 'node:path';

import type { db } from '@via/db';
import { transitServiceDates, transitStopDepartures } from '@via/db/schema';
import { sql } from 'drizzle-orm';

import {
  expandServiceDates,
  type CalendarDateRow,
  type CalendarRow,
} from './expand-service-dates';
import { parseGtfsTime } from './gtfs-time';

type Transaction = Parameters<Parameters<typeof db.transaction>[0]>[0];

export type ScheduledTrip = {
  routeId: string;
  directionId: number;
  headsign: string;
  serviceId: string;
};

type ImportSchedulesOptions = {
  gtfsPath: string;
  tx: Transaction;
  /** Every trip of the imported mode, keyed by trip id — not just the representative ones. */
  trips: Map<string, ScheduledTrip>;
  canonicalStopIdOf: (stopId: string) => string;
  /** Stations the network import actually inserted; calls elsewhere are skipped. */
  knownStopIds: Set<string>;
  readCsv: (path: string) => AsyncGenerator<Record<string, string>>;
};

const INSERT_BATCH = 5_000;

/**
 * The theoretical half of the import: re-streams `stop_times.txt` keeping the
 * departure times the network pass threw away, and expands the calendar files
 * into explicit service days. Runs inside the network transaction — the route
 * cascade has already emptied the previous departures, so a crash leaves
 * nothing half-written.
 */
export async function importSchedules({
  gtfsPath,
  tx,
  trips,
  canonicalStopIdOf,
  knownStopIds,
  readCsv,
}: ImportSchedulesOptions) {
  let batch: (typeof transitStopDepartures.$inferInsert)[] = [];
  let departureCount = 0;
  let skippedStops = 0;

  for await (const stopTime of readCsv(join(gtfsPath, 'stop_times.txt'))) {
    const trip = trips.get(stopTime.trip_id);
    if (!trip || !stopTime.departure_time) continue;

    const stopId = canonicalStopIdOf(stopTime.stop_id);
    if (!knownStopIds.has(stopId)) {
      // A branch the pattern selection dropped: its stations are not drawn,
      // so its departures would only ever dangle.
      skippedStops += 1;
      continue;
    }

    batch.push({
      stopId,
      routeId: trip.routeId,
      directionId: trip.directionId,
      headsign: trip.headsign,
      serviceId: trip.serviceId,
      departureSeconds: parseGtfsTime(stopTime.departure_time),
    });
    departureCount += 1;

    if (batch.length >= INSERT_BATCH) {
      await tx.insert(transitStopDepartures).values(batch);
      batch = [];
    }
  }
  if (batch.length > 0) await tx.insert(transitStopDepartures).values(batch);

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
      SELECT 1 FROM ${transitStopDepartures} AS departures
      WHERE departures.service_id = dates.service_id
    )
  `);

  console.log(
    `Imported ${departureCount} theoretical departures over ${serviceDates.length} service days` +
      (skippedStops > 0 ? ` (${skippedStops} calls on undrawn branches skipped).` : '.')
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

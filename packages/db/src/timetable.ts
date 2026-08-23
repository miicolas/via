import { sql, type SQLWrapper } from 'drizzle-orm';

import { transitProfileStops, transitTrips } from './schema';

/**
 * Reconstructs an absolute GTFS time from a trip start and a time-profile
 * offset. Keeping this expression here prevents timetable readers from
 * learning the compressed storage representation independently.
 */
export function absoluteTimetableSeconds(offset: SQLWrapper) {
  return sql<number>`${transitTrips.startSeconds} + ${offset}`.mapWith(Number);
}

/**
 * `import_meta` key holding the latest absolute second any call in the feed
 * reaches, written by the importer and read by the journey planner.
 *
 * GTFS times run past midnight — a service day is not a calendar day — so a
 * trip belonging to yesterday's service can still be running this morning, and
 * the planner has to search both days. How far past midnight is a property of
 * the feed, not a constant: the IDFM data currently tops out at 115 200
 * (32:00), so nothing from yesterday's service exists after 08:00 today.
 *
 * Measuring it once at import is what lets a reader skip a query whose WHERE
 * clause it can prove unsatisfiable, instead of paying 183 ms to be told there
 * are no rows. It is deliberately a measurement rather than a hardcoded 32:00:
 * a future feed with later night service would silently break that assumption,
 * and a reader that skipped on a stale constant would drop real departures.
 */
export const TIMETABLE_HORIZON_KEY = 'timetable:max-absolute-seconds';

/**
 * The feed's latest absolute call time. A full scan of `transit_profile_stops`,
 * so it belongs to the import, never to a request.
 */
export function maxAbsoluteTimetableSeconds() {
  return sql<{ seconds: number | null }>`
    SELECT max(${transitTrips.startSeconds} + ${transitProfileStops.departureOffset}) AS seconds
    FROM ${transitTrips}
    INNER JOIN ${transitProfileStops}
      ON ${transitProfileStops.profileKey} = ${transitTrips.profileKey}
  `;
}

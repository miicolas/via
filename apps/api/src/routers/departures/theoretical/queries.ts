import { db } from '@via/db';
import {
  transitProfileStops,
  transitServiceDates,
  transitStops,
  transitTrips,
} from '@via/db/schema';
import { absoluteTimetableSeconds } from '@via/db/timetable';
import { and, asc, eq, gt, inArray, sql } from 'drizzle-orm';

import type { TheoreticalDepartureRow } from './next-departures';

/**
 * Next scheduled departures at a stop on a service day, after a time of that
 * day. Absolute times are reconstructed from the trip's start and its time
 * profile's offset, so the filter and sort run on a computed column — the
 * candidate set is bounded by the profiles calling at one stop, which keeps
 * the top-N sort cheap without a dedicated index.
 *
 * The day's services resolve in a subquery rather than a prior round-trip —
 * their ids would only travel out of Postgres to come straight back in an `IN`
 * list — and the trailing `OFFSET 0` is what makes that subquery pay off.
 * Written plainly, the planner flattens it (or an equivalent join) into a
 * semi-join and probes `transit_service_dates` once per candidate trip: 45 000
 * index searches at La Défense, three quarters of the query's I/O. `OFFSET 0`
 * is Postgres' optimization fence — it forbids the pull-up, so the day's ~380
 * service ids are read once into a hash instead. Same rows, 62 746 buffers →
 * 17 141.
 *
 * Spelled as raw SQL because drizzle drops a `.offset(0)` on the floor: zero
 * reads as "no offset" to its query builder, and the fence disappears from the
 * emitted statement.
 */
export async function selectNextTheoreticalDepartures(
  stopId: string,
  serviceDate: string,
  afterSeconds: number,
  limit: number,
  routeIds: string[] = []
): Promise<TheoreticalDepartureRow[]> {
  const departureSeconds = absoluteTimetableSeconds(transitProfileStops.departureOffset);
  const runsOnServiceDate = sql`${transitTrips.serviceId} IN (
    SELECT ${transitServiceDates.serviceId}
    FROM ${transitServiceDates}
    WHERE ${transitServiceDates.date} = ${serviceDate}
    OFFSET 0
  )`;

  return db
    .select({
      routeId: transitTrips.routeId,
      headsign: transitTrips.headsign,
      departureSeconds,
    })
    .from(transitProfileStops)
    .innerJoin(transitTrips, eq(transitTrips.profileKey, transitProfileStops.profileKey))
    .innerJoin(transitStops, eq(transitStops.numericId, transitProfileStops.stopKey))
    .where(
      and(
        eq(transitStops.id, stopId),
        runsOnServiceDate,
        gt(departureSeconds, afterSeconds),
        routeIds.length > 0 ? inArray(transitTrips.routeId, routeIds) : undefined
      )
    )
    .orderBy(asc(departureSeconds))
    .limit(limit);
}

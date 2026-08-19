import { db } from '@via/db';
import {
  transitProfileStops,
  transitServiceDates,
  transitStops,
  transitTrips,
} from '@via/db/schema';
import { and, asc, eq, gt, sql } from 'drizzle-orm';

import type { TheoreticalDepartureRow } from './next-departures';

/**
 * Next scheduled departures at a stop on a service day, after a time of that
 * day. Absolute times are reconstructed from the trip's start and its time
 * profile's offset, so the filter and sort run on a computed column — the
 * candidate set is bounded by the profiles calling at one stop, which keeps
 * the top-N sort cheap without a dedicated index. The day's services resolve
 * in a subquery rather than a prior round-trip — their ids would only travel
 * out of Postgres to come straight back in an `IN` list.
 */
export async function selectNextTheoreticalDepartures(
  stopId: string,
  serviceDate: string,
  afterSeconds: number,
  limit: number
): Promise<TheoreticalDepartureRow[]> {
  const departureSeconds = sql<number>`${transitTrips.startSeconds} + ${transitProfileStops.departureOffset}`.mapWith(
    Number
  );
  return db
    .select({
      routeId: transitTrips.routeId,
      headsign: transitTrips.headsign,
      departureSeconds,
    })
    .from(transitProfileStops)
    .innerJoin(transitTrips, eq(transitTrips.profileKey, transitProfileStops.profileKey))
    .innerJoin(transitStops, eq(transitStops.numericId, transitProfileStops.stopKey))
    .innerJoin(transitServiceDates, eq(transitServiceDates.serviceId, transitTrips.serviceId))
    .where(
      and(
        eq(transitStops.id, stopId),
        eq(transitServiceDates.date, serviceDate),
        gt(departureSeconds, afterSeconds)
      )
    )
    .orderBy(asc(departureSeconds))
    .limit(limit);
}

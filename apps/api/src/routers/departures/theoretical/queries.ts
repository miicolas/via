import { db } from '@via/db';
import {
  transitServiceDates,
  transitStops,
  transitTripStopTimes,
  transitTrips,
} from '@via/db/schema';
import { and, asc, eq, gt } from 'drizzle-orm';

import type { TheoreticalDepartureRow } from './next-departures';

/**
 * Next scheduled departures at a stop on a service day, after a time of that
 * day. The day's services resolve in a subquery rather than a prior
 * round-trip — their ids would only travel out of Postgres to come straight
 * back in an `IN` list. Ordered and capped in SQL so the normalized stop-time
 * index does the work; route and headsign come from the trip row, avoiding a
 * second flat copy of every GTFS stop-time call.
 */
export async function selectNextTheoreticalDepartures(
  stopId: string,
  serviceDate: string,
  afterSeconds: number,
  limit: number
): Promise<TheoreticalDepartureRow[]> {
  return db
    .select({
      routeId: transitTrips.routeId,
      headsign: transitTrips.headsign,
      departureSeconds: transitTripStopTimes.departureSeconds,
    })
    .from(transitTripStopTimes)
    .innerJoin(transitTrips, eq(transitTrips.numericId, transitTripStopTimes.tripKey))
    .innerJoin(transitStops, eq(transitStops.numericId, transitTripStopTimes.stopKey))
    .innerJoin(transitServiceDates, eq(transitServiceDates.serviceId, transitTrips.serviceId))
    .where(
      and(
        eq(transitStops.id, stopId),
        eq(transitServiceDates.date, serviceDate),
        gt(transitTripStopTimes.departureSeconds, afterSeconds)
      )
    )
    .orderBy(asc(transitTripStopTimes.departureSeconds))
    .limit(limit);
}

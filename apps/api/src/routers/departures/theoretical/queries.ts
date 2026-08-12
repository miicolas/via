import { db } from '@via/db';
import { transitServiceDates, transitStopDepartures } from '@via/db/schema';
import { and, asc, eq, gt, inArray } from 'drizzle-orm';

import type { TheoreticalDepartureRow } from './next-departures';

/**
 * Next scheduled departures at a stop on a service day, after a time of that
 * day. The day's services resolve in a subquery rather than a prior
 * round-trip — their ids would only travel out of Postgres to come straight
 * back in an `IN` list. Ordered and capped in SQL so the index range scan does
 * the work — this is the query the `(stop, service, seconds)` index exists for.
 */
export async function selectNextTheoreticalDepartures(
  stopId: string,
  serviceDate: string,
  afterSeconds: number,
  limit: number
): Promise<TheoreticalDepartureRow[]> {
  const servicesOfDay = db
    .select({ serviceId: transitServiceDates.serviceId })
    .from(transitServiceDates)
    .where(eq(transitServiceDates.date, serviceDate));

  return db
    .select({
      routeId: transitStopDepartures.routeId,
      headsign: transitStopDepartures.headsign,
      departureSeconds: transitStopDepartures.departureSeconds,
    })
    .from(transitStopDepartures)
    .where(
      and(
        eq(transitStopDepartures.stopId, stopId),
        inArray(transitStopDepartures.serviceId, servicesOfDay),
        gt(transitStopDepartures.departureSeconds, afterSeconds)
      )
    )
    .orderBy(asc(transitStopDepartures.departureSeconds))
    .limit(limit);
}

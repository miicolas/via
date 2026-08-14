import { db } from '@via/db';
import { transitRoutes, transitStopRoutes } from '@via/db/schema';
import { and, eq } from 'drizzle-orm';

import { networkRouteCondition } from '@via/db/network-scope';

/**
 * The displayed routes calling at a station, with the columns their badges are
 * built from — recomputed server-side so the response never leaks another
 * line's visits from a shared PRIM payload.
 *
 * Empty array ⇒ the station id is unknown, which the handler turns into 404.
 */
export function selectStationRoutes(stationId: string) {
  return db
    .select({
      id: transitRoutes.id,
      shortName: transitRoutes.shortName,
      routeType: transitRoutes.routeType,
      color: transitRoutes.color,
      textColor: transitRoutes.textColor,
    })
    .from(transitStopRoutes)
    .innerJoin(transitRoutes, eq(transitStopRoutes.routeId, transitRoutes.id))
    .where(and(eq(transitStopRoutes.stopId, stationId), networkRouteCondition()))
    .orderBy(transitRoutes.id);
}

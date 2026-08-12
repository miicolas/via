import { db } from '@via/db';
import {
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db/schema';
import { and, eq } from 'drizzle-orm';

import { networkRouteCondition } from '../network-scope';

/**
 * The displayed routes calling at a station — server-side twin of the fact the
 * client already derives from `NetworkStation.positions`, recomputed here so
 * the response never leaks another line's visits from a shared PRIM payload.
 *
 * Empty array ⇒ the station id is unknown, which the handler turns into 404.
 */
export async function selectStationRouteIds(stationId: string): Promise<string[]> {
  const rows = await db
    .selectDistinct({ routeId: transitRoutes.id })
    .from(transitStops)
    .innerJoin(transitRoutePatternStops, eq(transitRoutePatternStops.stopId, transitStops.id))
    .innerJoin(
      transitRoutePatterns,
      eq(transitRoutePatternStops.patternId, transitRoutePatterns.id)
    )
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .where(and(eq(transitStops.id, stationId), networkRouteCondition()));

  return rows.map((row) => row.routeId);
}

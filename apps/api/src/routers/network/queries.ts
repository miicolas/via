import { db } from '@via/db';
import {
  ROUTE_TYPE,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db/schema';
import { nearestSnappedPoint } from '@via/db/projection';
import { and, asc, eq, isNotNull, sql } from 'drizzle-orm';

export function selectMetroPatterns() {
  return db
    .select({
      routeId: transitRoutes.id,
      shortName: transitRoutes.shortName,
      longName: transitRoutes.longName,
      color: transitRoutes.color,
      textColor: transitRoutes.textColor,
      patternId: transitRoutePatterns.id,
      geometry: sql<string>`ST_AsGeoJSON(${transitRoutePatterns.geometry})`,
    })
    .from(transitRoutePatterns)
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .where(eq(transitRoutes.routeType, ROUTE_TYPE.metro))
    .orderBy(asc(transitRoutes.shortName), asc(transitRoutePatterns.id));
}

export function selectMetroStationPositions() {
  const closestSnappedPoint = nearestSnappedPoint();

  return db
    .select({
      id: transitStops.id,
      name: transitStops.name,
      routeId: transitRoutes.id,
      longitude: sql<number>`ST_X(${closestSnappedPoint})`,
      latitude: sql<number>`ST_Y(${closestSnappedPoint})`,
    })
    .from(transitRoutePatternStops)
    .innerJoin(
      transitRoutePatterns,
      eq(transitRoutePatternStops.patternId, transitRoutePatterns.id)
    )
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .innerJoin(transitStops, eq(transitRoutePatternStops.stopId, transitStops.id))
    .where(
      and(
        eq(transitRoutes.routeType, ROUTE_TYPE.metro),
        isNotNull(transitRoutePatternStops.snappedLocation)
      )
    )
    .groupBy(transitStops.id, transitStops.name, transitRoutes.id)
    .orderBy(asc(transitStops.name), asc(transitRoutes.id));
}

export type MetroPatternRow = Awaited<ReturnType<typeof selectMetroPatterns>>[number];
export type MetroStationPositionRow = Awaited<
  ReturnType<typeof selectMetroStationPositions>
>[number];

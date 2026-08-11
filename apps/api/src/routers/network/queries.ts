import {
  db,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db';
import { and, asc, eq, isNotNull, sql } from 'drizzle-orm';

const METRO_ROUTE_TYPE = 1;

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
    .where(eq(transitRoutes.routeType, METRO_ROUTE_TYPE))
    .orderBy(asc(transitRoutes.shortName), asc(transitRoutePatterns.id));
}

export function selectMetroStationPositions() {
  const closestSnappedPoint = sql`(array_agg(${transitRoutePatternStops.snappedLocation} ORDER BY ST_Distance(${transitRoutePatternStops.snappedLocation}, ${transitStops.location})))[1]`;

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
        eq(transitRoutes.routeType, METRO_ROUTE_TYPE),
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

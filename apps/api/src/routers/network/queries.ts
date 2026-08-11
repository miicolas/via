import {
  db,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db';
import { asc, eq, sql } from 'drizzle-orm';

/** GTFS `route_type` 1 is "subway/metro" — the only mode the app renders today. */
const METRO_ROUTE_TYPE = 1;

/** One row per (route, pattern): every polyline the network is drawn from. */
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

/**
 * One row per (station, route), with the station projected onto that route's
 * track.
 *
 * GTFS records a station at its street entrance, which is tens of metres off the
 * alignment and sometimes on the wrong side of the road; snapping is what keeps
 * the dot *on* the line rather than floating beside it. `ST_Collect` unions every
 * pattern of the route first, so a station on a branch snaps to its own branch.
 */
export function selectMetroStationPositions() {
  return db
    .select({
      id: transitStops.id,
      name: transitStops.name,
      routeId: transitRoutes.id,
      longitude: sql<number>`ST_X(ST_ClosestPoint(ST_Collect(${transitRoutePatterns.geometry}), ${transitStops.location}))`,
      latitude: sql<number>`ST_Y(ST_ClosestPoint(ST_Collect(${transitRoutePatterns.geometry}), ${transitStops.location}))`,
    })
    .from(transitRoutePatternStops)
    .innerJoin(
      transitRoutePatterns,
      eq(transitRoutePatternStops.patternId, transitRoutePatterns.id)
    )
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .innerJoin(transitStops, eq(transitRoutePatternStops.stopId, transitStops.id))
    .where(eq(transitRoutes.routeType, METRO_ROUTE_TYPE))
    .groupBy(transitStops.id, transitStops.name, transitStops.location, transitRoutes.id)
    .orderBy(asc(transitStops.name), asc(transitRoutes.id));
}

/**
 * Exported so the mappers can be unit-tested against literal fixtures, without
 * importing drizzle or booting a database.
 */
export type MetroPatternRow = Awaited<ReturnType<typeof selectMetroPatterns>>[number];
export type MetroStationPositionRow = Awaited<
  ReturnType<typeof selectMetroStationPositions>
>[number];

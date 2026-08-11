import {
  db,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db';
import { and, asc, eq, isNotNull, sql } from 'drizzle-orm';

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
 * the dot *on* the line rather than floating beside it.
 *
 * The projection itself is precomputed at import time (see the importer), so this
 * only has to pick, among the patterns of the route that serve the station, the
 * one the station sits closest to. That is the same answer
 * `ST_ClosestPoint(ST_Collect(…))` used to compute per request — the closest point
 * on a union of lines is by definition the closest of the per-line closest points
 * — but without walking any track geometry.
 *
 * The ranking is a planar point-to-point distance, deliberately *not* the stored
 * `snapDistanceM`. The two disagree: at 48.9°N a degree of longitude is ~73 km
 * against ~111 km for a degree of latitude, so a mostly east-west offset measures
 * short in degrees and long in metres. Two of the 321 stations flip branch
 * between the metrics — Pré-Saint-Gervais sits 69.9 m from one 7bis pattern and
 * 72.8 m from the other, yet the planar order is reversed. Ranking in degrees is
 * what `ST_ClosestPoint` does, so ranking in degrees is what keeps the map
 * identical; `snapDistanceM` stays in metres because that is the number a human
 * reads when checking how far GTFS put a station from its track.
 */
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
        // Guards against a half-finished import leaving rows unprojected.
        isNotNull(transitRoutePatternStops.snappedLocation)
      )
    )
    .groupBy(transitStops.id, transitStops.name, transitRoutes.id)
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

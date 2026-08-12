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

/**
 * Two tracks closer than this are the same piece of line drawn twice — the
 * outbound and return patterns of a métro line run on parallel tracks a few
 * metres apart. Loops and branches sit far beyond it and survive as their own
 * strokes.
 */
const DUPLICATE_TRACK_TOLERANCE_METERS = 25;

export function selectMetroPatterns() {
  return db
    .select({
      routeId: transitRoutes.id,
      shortName: transitRoutes.shortName,
      longName: transitRoutes.longName,
      color: transitRoutes.color,
      textColor: transitRoutes.textColor,
      patternId: transitRoutePatterns.id,
      headsign: transitRoutePatterns.headsign,
      geometry: sql<string>`ST_AsGeoJSON(${dedupedPatternGeometry()})`,
    })
    .from(transitRoutePatterns)
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .where(eq(transitRoutes.routeType, ROUTE_TYPE.metro))
    .orderBy(asc(transitRoutes.shortName), asc(transitRoutePatterns.id));
}

/**
 * A pattern's geometry minus everything an earlier (longer) pattern of the same
 * route already draws.
 *
 * Each métro line arrives as one GTFS shape per direction — near-identical
 * polylines a few metres apart that render as a doubled stroke. Keeping only
 * what previous patterns have not covered collapses the return direction into
 * nothing where the tracks run together, while the parts where they genuinely
 * part ways — terminal loops, branches — stay. Patterns whose geometry empties
 * out keep their row: their headsign still names a destination.
 */
function dedupedPatternGeometry() {
  const geometry = transitRoutePatterns.geometry;
  // Longest first, so the fullest run of track is the reference the others are
  // compared against; empty for the first pattern of each route.
  const alreadyDrawn = sql`ST_Union(${geometry}) OVER (
    PARTITION BY ${transitRoutePatterns.routeId}
    ORDER BY ST_Length(${geometry}::geography) DESC, ${transitRoutePatterns.id}
    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
  )`;

  return sql`ST_LineMerge(ST_Difference(
    ${geometry},
    ST_Buffer(
      COALESCE(${alreadyDrawn}, ST_GeomFromText('LINESTRING EMPTY', 4326))::geography,
      ${DUPLICATE_TRACK_TOLERANCE_METERS}
    )::geometry
  ))`;
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

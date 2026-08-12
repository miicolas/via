import { db } from '@via/db';
import {
  ROUTE_TYPE,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db/schema';
import { and, asc, eq, exists, isNotNull, lt, notExists, or, sql } from 'drizzle-orm';
import { alias } from 'drizzle-orm/pg-core';

import {
  busRouteCondition,
  drawnRouteCondition,
  networkRouteCondition,
} from '../network-scope';

/**
 * Two tracks closer than this are the same piece of line drawn twice — the
 * outbound and return patterns of a métro line run on parallel tracks a few
 * metres apart. Loops and branches sit far beyond it and survive as their own
 * strokes.
 */
const DUPLICATE_TRACK_TOLERANCE_METERS = 25;

export function selectDrawnPatterns() {
  return db
    .select({
      routeId: transitRoutes.id,
      shortName: transitRoutes.shortName,
      longName: transitRoutes.longName,
      color: transitRoutes.color,
      textColor: transitRoutes.textColor,
      patternId: transitRoutePatterns.id,
      headsign: transitRoutePatterns.headsign,
      routeType: transitRoutes.routeType,
      isCanonical: transitRoutePatterns.isCanonical,
      geometry: sql<string>`ST_AsGeoJSON(${normalizedPatternGeometry()})`,
    })
    .from(transitRoutePatterns)
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .where(drawnRouteCondition())
    .orderBy(asc(transitRoutes.shortName), asc(transitRoutePatterns.id));
}

/** Bus calls and destinations are useful, but their shapes never enter PostGIS layout work. */
export function selectBusPatterns() {
  return db
    .select({
      routeId: transitRoutes.id,
      shortName: transitRoutes.shortName,
      longName: transitRoutes.longName,
      color: transitRoutes.color,
      textColor: transitRoutes.textColor,
      patternId: transitRoutePatterns.id,
      headsign: transitRoutePatterns.headsign,
      routeType: transitRoutes.routeType,
      isCanonical: transitRoutePatterns.isCanonical,
      geometry: sql<string>`'{"type":"LineString","coordinates":[]}'`,
    })
    .from(transitRoutePatterns)
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .where(busRouteCondition())
    .orderBy(asc(transitRoutes.shortName), asc(transitRoutePatterns.id));
}

/**
 * One centreline per route, plus only the branches that leave it.
 *
 * The importer has already chosen one canonical pattern for each route. It is
 * the stable visual spine: drawing it untouched avoids replacing pieces of it
 * with a return track whenever the two directions drift more than the duplicate
 * tolerance. A non-canonical pattern only contributes when it reaches a station
 * neither the canonical spine nor an earlier branch reaches; an opposite
 * direction cannot make a second line. Real branches and one-way terminal loops
 * are then reduced to track outside everything already retained.
 */
function normalizedPatternGeometry() {
  const geometry = transitRoutePatterns.geometry;
  const candidateStops = alias(transitRoutePatternStops, 'candidate_stops');
  const coveredStops = alias(transitRoutePatternStops, 'covered_stops');
  const coveringPatterns = alias(transitRoutePatterns, 'covering_patterns');
  const contributesBranch = exists(
    db
      .select({ value: sql`1` })
      .from(candidateStops)
      .where(
        and(
          eq(candidateStops.patternId, transitRoutePatterns.id),
          notExists(
            db
              .select({ value: sql`1` })
              .from(coveredStops)
              .innerJoin(
                coveringPatterns,
                eq(coveredStops.patternId, coveringPatterns.id)
              )
              .where(
                and(
                  eq(coveringPatterns.routeId, transitRoutePatterns.routeId),
                  or(
                    eq(coveringPatterns.isCanonical, true),
                    lt(coveringPatterns.id, transitRoutePatterns.id)
                  ),
                  eq(coveredStops.stopId, candidateStops.stopId)
                )
              )
          )
        )
      )
  );
  const canonicalGeometry = sql`ST_Union(${geometry}) FILTER (
    WHERE ${transitRoutePatterns.isCanonical}
  ) OVER (PARTITION BY ${transitRoutePatterns.routeId})`;
  const earlierBranches = sql`ST_Union(${geometry}) FILTER (
    WHERE NOT ${transitRoutePatterns.isCanonical}
  ) OVER (
    PARTITION BY ${transitRoutePatterns.routeId}
    ORDER BY ${transitRoutePatterns.id}
    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
  )`;
  const alreadyDrawn = sql`ST_Collect(
    COALESCE(${canonicalGeometry}, ST_GeomFromText('LINESTRING EMPTY', 4326)),
    COALESCE(${earlierBranches}, ST_GeomFromText('LINESTRING EMPTY', 4326))
  )`;

  return sql`CASE
    WHEN ${transitRoutePatterns.isCanonical} THEN ${geometry}
    WHEN ${contributesBranch} THEN ST_LineMerge(ST_Difference(
      ${geometry},
      ST_Buffer(${alreadyDrawn}::geography, ${DUPLICATE_TRACK_TOLERANCE_METERS})::geometry
    ))
    ELSE ST_GeomFromText('LINESTRING EMPTY', 4326)
  END`;
}

export function selectNetworkStationPositions() {
  // A shared stop exists on both direction patterns. Prefer its projection on
  // the canonical centreline that the map now draws; a branch-only stop has no
  // canonical candidate, so its closest branch projection naturally wins.
  const displayedSnappedPoint = sql`(array_agg(
    ${transitRoutePatternStops.snappedLocation}
    ORDER BY ${transitRoutePatterns.isCanonical} DESC,
             ${transitRoutePatternStops.snapDistanceM}
  ))[1]`;
  const displayedStationPoint = sql`COALESCE(
    ${displayedSnappedPoint},
    ${transitStops.location}
  )`;

  return db
    .select({
      id: transitStops.id,
      name: transitStops.name,
      routeId: transitRoutes.id,
      longitude: sql<number>`ST_X(${displayedStationPoint})`,
      latitude: sql<number>`ST_Y(${displayedStationPoint})`,
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
        networkRouteCondition(),
        or(
          eq(transitRoutes.routeType, ROUTE_TYPE.bus),
          isNotNull(transitRoutePatternStops.snappedLocation)
        )
      )
    )
    .groupBy(transitStops.id, transitStops.name, transitRoutes.id)
    .orderBy(asc(transitStops.name), asc(transitRoutes.id));
}

export type NetworkPatternRow = Awaited<ReturnType<typeof selectDrawnPatterns>>[number];
export type NetworkStationPositionRow = Awaited<
  ReturnType<typeof selectNetworkStationPositions>
>[number];

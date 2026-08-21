import type { StationsInAreaInput } from '@via/contract';
import { db } from '@via/db';
import {
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  stationFacts,
  transitStopRoutes,
  transitStops,
} from '@via/db/schema';
import { and, asc, eq, isNotNull, sql } from 'drizzle-orm';

import { drawnRouteCondition, networkRouteCondition } from '@via/db/network-scope';

import type { RouteBadgeRow } from '../route-badge';

/**
 * The métro and RER tracks, precomputed at import time (`@via/db/drawn-geometry`)
 * so this is a plain indexed read — the windowed PostGIS normalization that used
 * to run here cost seconds per request for a result that only changes when a
 * GTFS import runs.
 */
export function selectDrawnPatterns() {
  return db
    .select({
      routeId: transitRoutes.id,
      shortName: transitRoutes.shortName,
      color: transitRoutes.color,
      textColor: transitRoutes.textColor,
      routeType: transitRoutes.routeType,
      patternId: transitRoutePatterns.id,
      geometry: sql<string>`ST_AsGeoJSON(${transitRoutePatterns.drawnGeometry})`,
    })
    .from(transitRoutePatterns)
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .where(and(drawnRouteCondition(), isNotNull(transitRoutePatterns.drawnGeometry)))
    .orderBy(asc(transitRoutes.shortName), asc(transitRoutePatterns.id));
}

/** One row per (rail station, serving line), holding the snapped display point. */
export function selectRailStationPositions() {
  // A shared stop exists on both direction patterns. Prefer its projection on
  // the canonical centreline that the map draws; a branch-only stop has no
  // canonical candidate, so its closest branch projection naturally wins.
  const displayedSnappedPoint = sql`(array_agg(
    ${transitRoutePatternStops.snappedLocation}
    ORDER BY ${transitRoutePatterns.isCanonical} DESC,
             ${transitRoutePatternStops.snapDistanceM}
  ))[1]`;

  return db
    .select({
      id: transitStops.id,
      name: transitStops.name,
      routeId: transitRoutes.id,
      longitude: sql<number>`ST_X(${displayedSnappedPoint})`,
      latitude: sql<number>`ST_Y(${displayedSnappedPoint})`,
      accessibilityCondition: stationFacts.condition,
      accessibilityDetail: stationFacts.detail,
    })
    .from(transitRoutePatternStops)
    .innerJoin(
      transitRoutePatterns,
      eq(transitRoutePatternStops.patternId, transitRoutePatterns.id)
    )
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .innerJoin(transitStops, eq(transitRoutePatternStops.stopId, transitStops.id))
    .leftJoin(
      stationFacts,
      and(eq(stationFacts.stopId, transitStops.id), eq(stationFacts.kind, 'accessibility'))
    )
    .where(and(drawnRouteCondition(), isNotNull(transitRoutePatternStops.snappedLocation)))
    .groupBy(
      transitStops.id,
      transitStops.name,
      transitRoutes.id,
      stationFacts.condition,
      stationFacts.detail
    )
    .orderBy(asc(transitStops.name), asc(transitRoutes.id));
}

/**
 * Every served stop inside a small bounding box, with the badges of its lines.
 * `&&` against the GiST index on `location` makes the box the cheap part; the
 * contract caps the span, so the row count stays a neighbourhood, not a region.
 */
export function selectStationsInArea(area: StationsInAreaInput) {
  return db
    .select({
      id: transitStops.id,
      name: transitStops.name,
      longitude: sql<number>`ST_X(${transitStops.location})`,
      latitude: sql<number>`ST_Y(${transitStops.location})`,
      accessibilityCondition: stationFacts.condition,
      accessibilityDetail: stationFacts.detail,
      routes: sql<RouteBadgeRow[]>`json_agg(DISTINCT jsonb_build_object(
        'id', ${transitRoutes.id},
        'shortName', ${transitRoutes.shortName},
        'routeType', ${transitRoutes.routeType},
        'color', ${transitRoutes.color},
        'textColor', ${transitRoutes.textColor}
      ))`,
    })
    .from(transitStops)
    .innerJoin(transitStopRoutes, eq(transitStopRoutes.stopId, transitStops.id))
    .innerJoin(transitRoutes, eq(transitStopRoutes.routeId, transitRoutes.id))
    .leftJoin(
      stationFacts,
      and(eq(stationFacts.stopId, transitStops.id), eq(stationFacts.kind, 'accessibility'))
    )
    .where(
      and(
        networkRouteCondition(),
        sql`${transitStops.location} && ST_MakeEnvelope(
          ${area.minLongitude}, ${area.minLatitude},
          ${area.maxLongitude}, ${area.maxLatitude}, 4326)`
      )
    )
    .groupBy(
      transitStops.id,
      transitStops.name,
      stationFacts.condition,
      stationFacts.detail
    )
    .orderBy(asc(transitStops.name));
}

export type NetworkPatternRow = Awaited<ReturnType<typeof selectDrawnPatterns>>[number];
export type RailStationPositionRow = Awaited<
  ReturnType<typeof selectRailStationPositions>
>[number];
export type StationInAreaRow = Awaited<ReturnType<typeof selectStationsInArea>>[number];

import type { Coordinate } from '@via/contract';
import { db } from '@via/db';
import {
  stationFacts,
  transitRoutes,
  transitStopRoutes,
  transitStops,
  type AccessibilityStationFactCondition,
} from '@via/db/schema';
import { and, asc, eq, sql } from 'drizzle-orm';

import { networkRouteCondition } from '@via/db/network-scope';

import type { RouteBadgeRow } from '../route-badge';
import { looseLikePattern } from './like-pattern';

/**
 * Stations whose name contains the query, accents ignored on both sides so that
 * "repu" matches "République". `immutable_unaccent` is the IMMUTABLE wrapper
 * migration 0011 pairs with the trigram index — the expression here must stay
 * verbatim identical to the indexed one or the planner falls back to a scan.
 *
 * Ranking: prefix matches first, then earliest occurrence in the name, then
 * geodesic distance when the caller knows where the user is — `::geography`
 * because degrees lie about east-west distances at Paris' latitude, the same
 * rule `stop-projection.ts` documents — alphabetical otherwise.
 */
export function selectMatchingStations(
  query: string,
  limit: number,
  origin?: Coordinate
) {
  const normalizedName = sql`immutable_unaccent(lower(${transitStops.name}))`;
  // position() searches the literal text; LIKE additionally needs its
  // operators escaped. Same query, two spellings.
  const needle = sql`immutable_unaccent(lower(${query}))`;
  const likeNeedle = sql`immutable_unaccent(lower(${looseLikePattern(query)}))`;

  const tiebreaker = origin
    ? sql`ST_Distance(${transitStops.location}::geography, ST_SetSRID(ST_MakePoint(${origin.longitude}, ${origin.latitude}), 4326)::geography)`
    : sql`${transitStops.name}`;

  return db
    .select({
      id: transitStops.id,
      name: transitStops.name,
      longitude: sql<number>`ST_X(${transitStops.location})`,
      latitude: sql<number>`ST_Y(${transitStops.location})`,
      routes: sql<RouteBadgeRow[]>`json_agg(DISTINCT jsonb_build_object(
        'id', ${transitRoutes.id},
        'shortName', ${transitRoutes.shortName},
        'routeType', ${transitRoutes.routeType},
        'color', ${transitRoutes.color},
        'textColor', ${transitRoutes.textColor}
      ))`,
      accessibilityCondition: sql<AccessibilityStationFactCondition | null>`${stationFacts.condition}`,
      accessibilityDetail: stationFacts.detail,
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
        sql`${normalizedName} LIKE '%' || ${likeNeedle} || '%'`
      )
    )
    .groupBy(
      transitStops.id,
      stationFacts.stopId,
      stationFacts.kind
    )
    .orderBy(
      sql`(${normalizedName} LIKE ${likeNeedle} || '%') DESC`,
      sql`position(${needle} in ${normalizedName})`,
      asc(tiebreaker)
    )
    .limit(limit);
}

export type MatchingStationRow = Awaited<ReturnType<typeof selectMatchingStations>>[number];

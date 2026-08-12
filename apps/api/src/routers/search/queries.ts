import type { Coordinate } from '@via/contract';
import { db } from '@via/db';
import {
  ROUTE_TYPE,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStops,
} from '@via/db/schema';
import { and, asc, eq, sql } from 'drizzle-orm';

import { escapeLikePattern } from './like-pattern';

/**
 * Stations whose name contains the query, accents ignored on both sides so that
 * "repu" matches "République" (the `unaccent` extension, migration 0004).
 *
 * Ranking: prefix matches first, then earliest occurrence in the name, then
 * geodesic distance when the caller knows where the user is — `::geography`
 * because degrees lie about east-west distances at Paris' latitude, the same
 * rule `stop-projection.ts` documents — alphabetical otherwise.
 */
export function selectMatchingStations(query: string, limit: number, origin?: Coordinate) {
  const normalizedName = sql`unaccent(lower(${transitStops.name}))`;
  // position() searches the literal text; LIKE additionally needs its
  // operators escaped. Same query, two spellings.
  const needle = sql`unaccent(lower(${query}))`;
  const likeNeedle = sql`unaccent(lower(${escapeLikePattern(query)}))`;

  const tiebreaker = origin
    ? sql`ST_Distance(${transitStops.location}::geography, ST_SetSRID(ST_MakePoint(${origin.longitude}, ${origin.latitude}), 4326)::geography)`
    : sql`${transitStops.name}`;

  return db
    .select({
      id: transitStops.id,
      name: transitStops.name,
      longitude: sql<number>`ST_X(${transitStops.location})`,
      latitude: sql<number>`ST_Y(${transitStops.location})`,
      routeIds: sql<string[]>`array_agg(DISTINCT ${transitRoutes.id})`,
    })
    .from(transitStops)
    .innerJoin(transitRoutePatternStops, eq(transitRoutePatternStops.stopId, transitStops.id))
    .innerJoin(
      transitRoutePatterns,
      eq(transitRoutePatternStops.patternId, transitRoutePatterns.id)
    )
    .innerJoin(transitRoutes, eq(transitRoutePatterns.routeId, transitRoutes.id))
    .where(
      and(
        eq(transitRoutes.routeType, ROUTE_TYPE.metro),
        sql`${normalizedName} LIKE '%' || ${likeNeedle} || '%'`
      )
    )
    .groupBy(transitStops.id)
    .orderBy(
      sql`(${normalizedName} LIKE ${likeNeedle} || '%') DESC`,
      sql`position(${needle} in ${normalizedName})`,
      asc(tiebreaker)
    )
    .limit(limit);
}

export type MatchingStationRow = Awaited<ReturnType<typeof selectMatchingStations>>[number];

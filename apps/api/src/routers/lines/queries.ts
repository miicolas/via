import { db } from '@via/db';
import { networkRouteCondition, drawnRouteCondition } from '@via/db/network-scope';
import {
  transitLineDirections,
  transitLineSchemaStops,
  transitRoutePatterns,
  transitRoutePatternStops,
  transitRoutes,
  transitStopRoutes,
  transitStops,
} from '@via/db/schema';
import { and, asc, desc, eq, ilike, or, sql } from 'drizzle-orm';

const routeColumns = {
  id: transitRoutes.id,
  shortName: transitRoutes.shortName,
  longName: transitRoutes.longName,
  routeType: transitRoutes.routeType,
  color: transitRoutes.color,
  textColor: transitRoutes.textColor,
};

/** Every line of the rail network the tab lists permanently. */
export function selectRailLines() {
  return db.select(routeColumns).from(transitRoutes).where(drawnRouteCondition());
}

/**
 * Lines of any mode — buses included — matching the query. A short code
 * matches by prefix ("38" finds the 38 and 380), a longer text anywhere in the
 * long name.
 */
export function selectLinesMatching(query: string, limit: number) {
  return db
    .select(routeColumns)
    .from(transitRoutes)
    .where(
      and(
        networkRouteCondition(),
        or(ilike(transitRoutes.shortName, `${query}%`), ilike(transitRoutes.longName, `%${query}%`))
      )
    )
    .orderBy(
      // Exact code first, then shortest code — "38" before "380" and "384".
      desc(sql`${transitRoutes.shortName} ILIKE ${query}`),
      asc(sql`length(${transitRoutes.shortName})`),
      asc(transitRoutes.shortName)
    )
    .limit(limit);
}

export function selectLineById(lineId: string) {
  return db.select(routeColumns).from(transitRoutes).where(eq(transitRoutes.id, lineId)).limit(1);
}

/**
 * One row per (selected pattern, stop) of the line, in travel order. The
 * pattern set was already curated at import time: one canonical pattern per
 * direction plus the real branches.
 */
export function selectLineBranchStops(lineId: string) {
  return db
    .select({
      patternId: transitRoutePatterns.id,
      directionId: transitRoutePatterns.directionId,
      headsign: transitRoutePatterns.headsign,
      isCanonical: transitRoutePatterns.isCanonical,
      tripCount: transitRoutePatterns.tripCount,
      stopId: transitStops.id,
      stopName: transitStops.name,
      stopSequence: transitRoutePatternStops.stopSequence,
    })
    .from(transitRoutePatternStops)
    .innerJoin(
      transitRoutePatterns,
      eq(transitRoutePatternStops.patternId, transitRoutePatterns.id)
    )
    .innerJoin(transitStops, eq(transitRoutePatternStops.stopId, transitStops.id))
    .where(eq(transitRoutePatterns.routeId, lineId))
    .orderBy(
      asc(transitRoutePatterns.directionId),
      desc(transitRoutePatterns.isCanonical),
      desc(transitRoutePatterns.tripCount),
      asc(transitRoutePatterns.id),
      asc(transitRoutePatternStops.stopSequence)
    );
}

/**
 * One row per station of the line's complete schema, in render order. Unlike
 * the pattern rows above — one mission's calls — this table was merged from
 * every trip at import time, so no station is missing. `isInterchange` marks
 * stations served by at least one *other* drawn line; buses don't count.
 */
export function selectLineSchemaStops(lineId: string) {
  return db
    .select({
      directionId: transitLineSchemaStops.directionId,
      directionLabel: transitLineDirections.label,
      sectionIndex: transitLineSchemaStops.sectionIndex,
      sectionRole: transitLineSchemaStops.sectionRole,
      sectionLabel: transitLineSchemaStops.sectionLabel,
      sectionOrigins: transitLineSchemaStops.sectionOrigins,
      sectionTermini: transitLineSchemaStops.sectionTermini,
      stopId: transitStops.id,
      stopName: transitStops.name,
      isInterchange: sql<boolean>`EXISTS (
        SELECT 1
        FROM ${transitStopRoutes}
        INNER JOIN ${transitRoutes} ON ${transitRoutes.id} = ${transitStopRoutes.routeId}
        WHERE ${transitStopRoutes.stopId} = ${transitStops.id}
          AND ${transitStopRoutes.routeId} <> ${lineId}
          AND ${drawnRouteCondition()}
      )`,
    })
    .from(transitLineSchemaStops)
    .innerJoin(transitStops, eq(transitLineSchemaStops.stopId, transitStops.id))
    .innerJoin(
      transitLineDirections,
      and(
        eq(transitLineDirections.routeId, transitLineSchemaStops.routeId),
        eq(transitLineDirections.directionId, transitLineSchemaStops.directionId)
      )
    )
    .where(eq(transitLineSchemaStops.routeId, lineId))
    .orderBy(
      asc(transitLineSchemaStops.directionId),
      asc(transitLineSchemaStops.sectionIndex),
      asc(transitLineSchemaStops.position)
    );
}

export type LineRow = Awaited<ReturnType<typeof selectRailLines>>[number];
export type LineBranchStopRow = Awaited<ReturnType<typeof selectLineBranchStops>>[number];
export type LineSchemaStopRow = Awaited<ReturnType<typeof selectLineSchemaStops>>[number];

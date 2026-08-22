import { and, eq, gte, lte } from 'drizzle-orm';
import { jobDb, transitRoutePatternStops, transitRoutePatterns } from '@via/db';
import type { ImpactedSection } from '../routers/lines/disruptions/parse';
import { bareStopId } from '../routers/idfm/stop-ids';

/**
 * Expands disruption sections to canonical stations once per snapshot cycle.
 * Pattern stops are the only source that knows the order of calls on each
 * branch; following a station therefore remains a bounded indexed join.
 */
export async function impactedStopIds(
  sections: readonly ImpactedSection[],
): Promise<ReadonlySet<string>> {
  const result = new Set<string>();
  for (const section of sections) {
    const fromStopId = bareStopId(section.fromStopId) ?? section.fromStopId;
    const toStopId = bareStopId(section.toStopId) ?? section.toStopId;
    const patterns = await jobDb
      .select({ patternId: transitRoutePatterns.id })
      .from(transitRoutePatterns)
      .where(eq(transitRoutePatterns.routeId, section.routeId));

    for (const pattern of patterns) {
      const bounds = await jobDb
        .select({
          stopId: transitRoutePatternStops.stopId,
          stopSequence: transitRoutePatternStops.stopSequence,
        })
        .from(transitRoutePatternStops)
        .where(
          eq(transitRoutePatternStops.patternId, pattern.patternId),
        );
      const from = bounds.find((stop) => stop.stopId === fromStopId)?.stopSequence;
      const to = bounds.find((stop) => stop.stopId === toStopId)?.stopSequence;
      if (from === undefined || to === undefined) continue;
      const low = Math.min(from, to);
      const high = Math.max(from, to);
      const sectionStops = await jobDb
        .select({ stopId: transitRoutePatternStops.stopId })
        .from(transitRoutePatternStops)
        .where(
          and(
            eq(transitRoutePatternStops.patternId, pattern.patternId),
            gte(transitRoutePatternStops.stopSequence, low),
            lte(transitRoutePatternStops.stopSequence, high),
          ),
        );
      for (const stop of sectionStops) result.add(bareStopId(stop.stopId) ?? stop.stopId);
    }
  }
  return result;
}

/**
 * Which stops a journey may start from, or end at, given a point on the map.
 *
 * Policy on the planner side of the loader seam: the loader only fetches by
 * distance, so the rule that decides whether a whole town is reachable stays
 * readable — and testable — without a network.
 */

import type { Coordinate } from '@via/contract';

import type { GtfsPlannerLoader, PlannerStop } from './planner';
import type { SearchBudget } from './search-budget';

/**
 * The stops a search may enter or leave the network through around one point:
 * the nearest stops of any mode, plus reserved slots for the nearest
 * structuring station — see `SearchBudget.structuringAccessStops` for why a
 * suburb needs the reservation at all.
 */
export async function accessStopsAround(
  nearbyStops: GtfsPlannerLoader['nearbyStops'],
  coordinate: Coordinate,
  budget: SearchBudget,
  stationId?: string
): Promise<PlannerStop[]> {
  // A named stop is the traveller's own choice: it wins outright, and no
  // reserved slot may widen what they pinned.
  if (stationId) return nearbyStops(coordinate, budget.maxAccessStops, { stationId });

  const [nearest, structuring] = await Promise.all([
    nearbyStops(coordinate, budget.maxAccessStops, {}),
    nearbyStops(coordinate, budget.structuringAccessStops, { structuringOnly: true }),
  ]);
  return mergeAccessStops(nearest, structuring);
}

/**
 * The nearest stops of any mode, plus the nearest stations, each list already
 * ordered by distance and neither dropping the other's entries.
 *
 * The result can exceed either list's own limit: the reserved slots are an
 * addition to the access set, not a share of it.
 */
export function mergeAccessStops<T extends { id: string }>(
  nearest: readonly T[],
  structuring: readonly T[]
): T[] {
  const merged: T[] = [];
  const seen = new Set<string>();
  for (const stop of [...nearest, ...structuring]) {
    if (seen.has(stop.id)) continue;
    seen.add(stop.id);
    merged.push(stop);
  }
  return merged;
}

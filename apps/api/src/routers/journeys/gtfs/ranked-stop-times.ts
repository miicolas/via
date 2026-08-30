import type { GtfsPlannerLoader, PlannerStopTime } from './planner';
import type { SearchBudget } from './search-budget';
import {
  boundGroups,
  rankStopTimeCandidates,
  type StopTimeDirection,
} from './stop-time-candidates';

/**
 * The boardings — or, backward, alightings — one round of the search may
 * explore: the frontier grouped into shared queries, the raw rows ranked by
 * waiting time, and each stop capped at `budget.maxBoardingsPerStop` so a
 * dense stop's every departure cannot drown the rest of the frontier.
 *
 * Policy lives here, on the planner side of the loader seam: the loader only
 * fetches, so a fake loader exercises these rules unchanged.
 */
export async function rankedStopTimes(
  direction: StopTimeDirection,
  loader: Pick<GtfsPlannerLoader, 'stopTimes'>,
  boundByStop: Map<string, number>,
  serviceDates: string[],
  budget: SearchBudget
): Promise<PlannerStopTime[]> {
  const stops = [...boundByStop].map(([stopId, bound]) => ({ stopId, bound }));
  const groups = boundGroups(
    direction,
    stops,
    budget.maxBoundGroups,
    budget.boundGroupSpreadSeconds
  );
  if (groups.length === 0) return [];
  const candidates = await loader.stopTimes(
    direction,
    groups,
    serviceDates,
    budget.maxStopTimeCandidates
  );
  const ranked = rankStopTimeCandidates(
    direction,
    candidates,
    (stopId) => boundByStop.get(stopId),
    budget.maxStopTimeCandidates
  );
  const counts = new Map<string, number>();
  return ranked.filter((row) => {
    const count = counts.get(row.stopId) ?? 0;
    if (count >= budget.maxBoardingsPerStop) return false;
    counts.set(row.stopId, count + 1);
    return true;
  });
}

/**
 * How a round of the GTFS search turns its frontier into timetable queries, and
 * which of the rows they return survive the candidate ceiling.
 *
 * Pure on purpose: the rules below decide whether a long journey is findable at
 * all, and they must be readable — and testable — without a timetable.
 */

import { DEFAULT_SEARCH_BUDGET } from './search-budget';

/** 'board' walks departures forward in time; 'alight' walks arrivals backward. */
export type StopTimeDirection = 'board' | 'alight';

/**
 * Splits the frontier into groups that can share one candidate query.
 *
 * A candidate query walks the timetable from a single bound and stops at the
 * candidate ceiling, so every stop in it competes for that budget in absolute
 * time. That is fair only while the frontier is reached at roughly the same
 * moment. Over a long journey it is not: a later round holds stops a
 * two-minute walk away and stops reached forty minutes later by train, and the
 * near ones — dense, frequent, already explored — exhaust the budget before
 * the far one's first departure is even read. The far stop then has no
 * boarding at all, and the leg that would have continued the journey is never
 * explored. That is why a suburban origin could come back with no transit
 * route while the same destination answered from inside Paris.
 *
 * Grouping by bound gives each time window its own budget. A frontier reached
 * within `spreadSeconds` stays a single group, so short searches keep making
 * exactly one query per service day.
 */
export function boundGroups(
  direction: StopTimeDirection,
  stops: Array<{ stopId: string; bound: number }>,
  maxGroups = DEFAULT_SEARCH_BUDGET.maxBoundGroups,
  spreadSeconds = DEFAULT_SEARCH_BUDGET.boundGroupSpreadSeconds
): Array<{ stopIds: string[]; bound: number }> {
  if (stops.length === 0) return [];
  // 'board' searches forward from the earliest bound, 'alight' backward from
  // the latest: either way a group's own bound is the first one in this order.
  const ordered = [...stops].sort((a, b) =>
    direction === 'board' ? a.bound - b.bound : b.bound - a.bound
  );
  const spread = Math.abs(ordered.at(-1)!.bound - ordered[0]!.bound);
  const groupCount = spread <= spreadSeconds ? 1 : Math.min(maxGroups, ordered.length);
  const size = Math.ceil(ordered.length / groupCount);
  const groups: Array<{ stopIds: string[]; bound: number }> = [];
  for (let start = 0; start < ordered.length; start += size) {
    const slice = ordered.slice(start, start + size);
    groups.push({ stopIds: slice.map((stop) => stop.stopId), bound: slice[0]!.bound });
  }
  return groups;
}

/**
 * Orders candidates by how long the traveller waits at their own stop rather
 * than by the clock, then keeps `limit` of them.
 *
 * Absolute time is the wrong scale once the frontier spans a whole leg: it
 * ranks a bus leaving in one minute from a stop reached in one minute above the
 * train leaving in two minutes from a stop reached in forty. Waiting time is
 * the same scale everywhere, so the ceiling trims the departures nobody would
 * take instead of the far end of the search.
 */
export function rankStopTimeCandidates<T extends { stopId: string; seconds: number }>(
  direction: StopTimeDirection,
  candidates: T[],
  boundOf: (stopId: string) => number | undefined,
  limit = DEFAULT_SEARCH_BUDGET.maxStopTimeCandidates
): T[] {
  return candidates
    .flatMap((candidate) => {
      const bound = boundOf(candidate.stopId);
      if (bound === undefined) return [];
      const wait = direction === 'board'
        ? candidate.seconds - bound
        : bound - candidate.seconds;
      // A shared query answers from its group's bound, so it can return rows
      // that are already past for this particular stop.
      return wait < 0 ? [] : [{ candidate, wait }];
    })
    .sort((a, b) => a.wait - b.wait)
    .slice(0, limit)
    .map((entry) => entry.candidate);
}

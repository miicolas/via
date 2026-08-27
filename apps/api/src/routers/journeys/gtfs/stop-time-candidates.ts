/**
 * How a round of the GTFS search turns its frontier into timetable queries, and
 * which of the rows they return survive the candidate ceiling.
 *
 * Pure on purpose: the rules below decide whether a long journey is findable at
 * all, and they must be readable — and testable — without a timetable.
 */

/** Per-stop ceiling applied by the loader once candidates are ranked. */
export const MAX_BOARDINGS_PER_STOP = 32;
/** Rows a single candidate query may return, and the ceiling after merging. */
export const MAX_BOARDING_CANDIDATES = 1_500;

/**
 * How far apart two frontier stops may be reached before they stop sharing a
 * candidate query. Below it the frontier is one time window and one query, the
 * behaviour every short search has always had.
 */
export const BOUND_GROUP_SPREAD_SECONDS = 300;
/** Ceiling on the extra queries a widely spread frontier may cost. */
export const MAX_BOUND_GROUPS = 4;

/** 'board' walks departures forward in time; 'alight' walks arrivals backward. */
export type StopTimeDirection = 'board' | 'alight';

export type StopTimeCandidate = {
  tripId: string;
  stopKey: number;
  seconds: number;
  serviceDate: string;
};

/**
 * Splits the frontier into groups that can share one candidate query.
 *
 * A candidate query walks the timetable from a single bound and stops at
 * {@link MAX_BOARDING_CANDIDATES} rows, so every stop in it competes for that
 * budget in absolute time. That is fair only while the frontier is reached at
 * roughly the same moment. Over a long journey it is not: a later round holds
 * stops a two-minute walk away and stops reached forty minutes later by train,
 * and the near ones — dense, frequent, already explored — exhaust the budget
 * before the far one's first departure is even read. The far stop then has no
 * boarding at all, and the leg that would have continued the journey is never
 * explored. That is why a suburban origin could come back with no transit route
 * while the same destination answered from inside Paris.
 *
 * Grouping by bound gives each time window its own budget. A frontier reached
 * within {@link BOUND_GROUP_SPREAD_SECONDS} stays a single group, so short
 * searches keep making exactly one query per service day.
 */
export function boundGroups(
  direction: StopTimeDirection,
  stops: Array<{ stopKey: number; bound: number }>,
  maxGroups = MAX_BOUND_GROUPS,
  spreadSeconds = BOUND_GROUP_SPREAD_SECONDS
): Array<{ stopKeys: number[]; bound: number }> {
  if (stops.length === 0) return [];
  // 'board' searches forward from the earliest bound, 'alight' backward from
  // the latest: either way a group's own bound is the first one in this order.
  const ordered = [...stops].sort((a, b) =>
    direction === 'board' ? a.bound - b.bound : b.bound - a.bound
  );
  const spread = Math.abs(ordered.at(-1)!.bound - ordered[0]!.bound);
  const groupCount = spread <= spreadSeconds ? 1 : Math.min(maxGroups, ordered.length);
  const size = Math.ceil(ordered.length / groupCount);
  const groups: Array<{ stopKeys: number[]; bound: number }> = [];
  for (let start = 0; start < ordered.length; start += size) {
    const slice = ordered.slice(start, start + size);
    groups.push({ stopKeys: slice.map((stop) => stop.stopKey), bound: slice[0]!.bound });
  }
  return groups;
}

/**
 * Orders candidates by how long the traveller waits at their own stop rather
 * than by the clock, then keeps {@link MAX_BOARDING_CANDIDATES} of them.
 *
 * Absolute time is the wrong scale once the frontier spans a whole leg: it
 * ranks a bus leaving in one minute from a stop reached in one minute above the
 * train leaving in two minutes from a stop reached in forty. Waiting time is
 * the same scale everywhere, so the ceiling trims the departures nobody would
 * take instead of the far end of the search.
 */
export function rankStopTimeCandidates(
  direction: StopTimeDirection,
  candidates: StopTimeCandidate[],
  boundOf: (stopKey: number) => number | undefined,
  limit = MAX_BOARDING_CANDIDATES
): StopTimeCandidate[] {
  return candidates
    .flatMap((candidate) => {
      const bound = boundOf(candidate.stopKey);
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

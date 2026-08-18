import type { DisruptionPeriod } from './parse';

/** Seven days: the horizon the Lines tab shows for planned closures. */
export const UPCOMING_HORIZON_SECONDS = 7 * 24 * 3600;

export type DisruptionActivity =
  | { kind: 'active' }
  | { kind: 'upcoming'; beginsAt: number }
  | { kind: 'inactive' };

/**
 * Where a disruption sits relative to now: running, starting within the
 * horizon (earliest such start wins), or neither — past, or too far out to
 * show yet.
 */
export function activityOf(
  periods: DisruptionPeriod[],
  nowSeconds: number,
  horizonSeconds: number = UPCOMING_HORIZON_SECONDS
): DisruptionActivity {
  let earliestUpcoming: number | undefined;

  for (const period of periods) {
    if (period.beginsAt <= nowSeconds && nowSeconds <= period.endsAt) return { kind: 'active' };
    if (period.beginsAt > nowSeconds && period.beginsAt <= nowSeconds + horizonSeconds) {
      earliestUpcoming = Math.min(earliestUpcoming ?? Infinity, period.beginsAt);
    }
  }

  return earliestUpcoming === undefined
    ? { kind: 'inactive' }
    : { kind: 'upcoming', beginsAt: earliestUpcoming };
}

import type { RedisClient } from '../../redis';
import { parisServiceDay } from './theoretical/service-day';

/**
 * Kept below the configured ceiling so a race near the limit — or a stray
 * curl — never spends the very last PRIM requests of the day.
 */
const SAFETY_RESERVE_RATIO = 0.05;

/** Counter keys outlive their day by enough to observe yesterday, then vanish. */
const COUNTER_TTL_SECONDS = 48 * 3600;

/** One counter for the whole PRIM stop-monitoring quota. */
const COUNTER_KEY_PREFIX = 'prim:budget:stop-monitoring';

export type PrimBudgetScope = 'stop-monitoring' | 'journeys';

export type BudgetDecision = {
  allowed: boolean;
  /**
   * Consumption relative to where it should be at this hour if spending were
   * spread evenly across the day. Above 1 means burning too fast — the TTL
   * governor slows the refresh rate in response.
   */
  ratio: number;
};

/**
 * Increment-first token accounting on a per-day Redis key: atomic across
 * serverless instances, and a denial costs nothing real since no PRIM call
 * follows it. Redis being down counts as a denial — with no shared counter we
 * could not prove the quota is respected, and the quota matters more than one
 * refresh. Day boundary in Europe/Paris, where the PRIM counter resets.
 */
export async function tryConsumeBudget(
  redis: RedisClient,
  dailyBudget: number,
  now: Date,
  scope: PrimBudgetScope = 'stop-monitoring'
): Promise<BudgetDecision> {
  // The same Paris clock as the schedule, so the budget day and the service
  // day can never disagree at a DST edge.
  const { date, seconds } = parisServiceDay(now);
  const key = `${scope === 'journeys' ? 'prim:budget:journeys' : COUNTER_KEY_PREFIX}:${date}`;

  try {
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, COUNTER_TTL_SECONDS);

    const ceiling = dailyBudget * (1 - SAFETY_RESERVE_RATIO);
    return { allowed: count <= ceiling, ratio: count / expectedByNow(dailyBudget, seconds) };
  } catch (cause) {
    console.error('[departures] budget Redis indisponible', cause);
    return { allowed: false, ratio: Number.POSITIVE_INFINITY };
  }
}

function expectedByNow(dailyBudget: number, secondsIntoDay: number): number {
  // The early-morning floor keeps the ratio meaningful at 00:05, when even one
  // request would otherwise look like a runaway burn.
  return Math.max(dailyBudget * (secondsIntoDay / 86_400), dailyBudget * 0.02);
}

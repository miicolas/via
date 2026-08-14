import type { RedisClient } from '../../redis';
import { parisDay } from '../../time/paris';

/** Keep a reserve for races near the provider's hard daily ceiling. */
const SAFETY_RESERVE_RATIO = 0.05;
const COUNTER_TTL_SECONDS = 48 * 3600;

export type DailyIdfmBudgetDecision = {
  allowed: boolean;
  /** Consumption relative to an even spend at the current Paris time. */
  ratio: number;
};

type DailyIdfmBudgetInput = {
  dailyBudget: number;
  now: Date;
  counterKeyPrefix: string;
};

/**
 * Feature-neutral IDFM quota accounting. The caller owns the product policy:
 * this module only atomically spends one daily token and reports the result.
 * Redis failures deliberately propagate so each caller can choose its fallback.
 */
export async function tryConsumeDailyIdfmBudget(
  redis: RedisClient,
  { dailyBudget, now, counterKeyPrefix }: DailyIdfmBudgetInput
): Promise<DailyIdfmBudgetDecision> {
  const { date, seconds } = parisDay(now);
  const key = `${counterKeyPrefix}:${date}`;
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, COUNTER_TTL_SECONDS);

  const ceiling = dailyBudget * (1 - SAFETY_RESERVE_RATIO);
  return { allowed: count <= ceiling, ratio: count / expectedByNow(dailyBudget, seconds) };
}

function expectedByNow(dailyBudget: number, secondsIntoDay: number): number {
  return Math.max(dailyBudget * (secondsIntoDay / 86_400), dailyBudget * 0.02);
}

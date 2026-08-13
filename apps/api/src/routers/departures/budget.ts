import type { RedisClient } from '../../redis';
import {
  tryConsumeDailyIdfmBudget,
  type DailyIdfmBudgetDecision,
} from '../idfm/daily-budget';

const COUNTER_KEY_PREFIX = 'prim:budget:stop-monitoring';

/**
 * Departure-specific policy around the shared IDFM daily counter. Losing Redis
 * denies realtime refreshes because the shared provider quota cannot be proven.
 */
export async function tryConsumeBudget(
  redis: RedisClient,
  dailyBudget: number,
  now: Date
): Promise<DailyIdfmBudgetDecision> {
  try {
    return await tryConsumeDailyIdfmBudget(redis, {
      dailyBudget,
      now,
      counterKeyPrefix: COUNTER_KEY_PREFIX,
    });
  } catch (cause) {
    console.error('[departures] budget Redis indisponible', cause);
    return { allowed: false, ratio: Number.POSITIVE_INFINITY };
  }
}

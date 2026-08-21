import type { RedisClient } from '../../redis';

export type CircuitBreakerConfig = {
  /** Consecutive failures that trip the breaker. */
  failureThreshold: number;
  /** How long the breaker stays open once tripped, in seconds. */
  openSeconds: number;
};

/**
 * A shared OpenAI circuit breaker. Redis-backed so every API instance sees the
 * same open state: once one instance trips it, the others stop calling OpenAI
 * too, instead of each discovering the outage on its own.
 *
 * "Consecutive" is deliberate — a single success clears the counter, so a burst
 * of unrelated hiccups spread across healthy calls never accumulates into a trip.
 */
export type CircuitBreaker = {
  isOpen: () => Promise<boolean>;
  recordSuccess: () => Promise<void>;
  recordFailure: () => Promise<void>;
};

const OPEN_KEY = 'openai:breaker:open';
const FAILURES_KEY = 'openai:breaker:failures';

export function createCircuitBreaker(
  redis: RedisClient,
  { failureThreshold, openSeconds }: CircuitBreakerConfig
): CircuitBreaker {
  return {
    isOpen: async () => (await redis.get<string>(OPEN_KEY)) !== null,
    recordSuccess: async () => {
      await redis.del(FAILURES_KEY);
    },
    recordFailure: async () => {
      const failures = await redis.incr(FAILURES_KEY);
      // Keep the counter from outliving a quiet period: a lone failure with no
      // follow-up should decay rather than pre-load the next trip.
      if (failures === 1) await redis.expire(FAILURES_KEY, openSeconds);
      if (failures >= failureThreshold) {
        await redis.set(OPEN_KEY, '1', { ex: openSeconds });
        await redis.del(FAILURES_KEY);
      }
    },
  };
}

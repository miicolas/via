import type { RedisClient } from '../redis';

/**
 * Increments a fixed-window counter and starts its expiry on the first hit.
 * The operation is intentionally tiny: feature-specific limiters decide the
 * key namespace and whether Redis errors fail open or closed.
 */
export async function incrementFixedWindow(
  redis: RedisClient,
  key: string,
  windowSeconds: number
) {
  if (!Number.isInteger(windowSeconds) || windowSeconds < 1) {
    throw new Error('A rate-limit window needs a positive integer duration');
  }

  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, windowSeconds);
  return count;
}

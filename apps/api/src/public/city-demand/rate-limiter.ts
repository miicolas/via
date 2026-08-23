import type { RedisClient } from '../../redis';

const DAY_SECONDS = 24 * 60 * 60;

/**
 * The catalogue is twelve cities and the primary key already refuses a second
 * vote for the same one, so a sincere visitor never comes close to this ceiling
 * — it exists to cap what a single address can spend a day pushing.
 */
const DAILY_VOTES_PER_ADDRESS = 24;

/**
 * Fail-open, unlike the report limiter: this is a marketing poll, and a Redis
 * blip must not turn the coverage map into a dead end. The primary key still
 * holds the line that matters.
 */
export async function withinCityVoteQuota(redis: RedisClient, voterHash: string) {
  try {
    const key = `city-demand:day:${voterHash}`;
    const votes = await redis.incr(key);
    if (votes === 1) await redis.expire(key, DAY_SECONDS);
    return votes <= DAILY_VOTES_PER_ADDRESS;
  } catch {
    return true;
  }
}

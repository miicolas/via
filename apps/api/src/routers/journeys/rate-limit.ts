import { createHash } from 'node:crypto';

import type { RedisClient } from '../../redis';

export type PersonalJourneyDecision = { allowed: boolean; count: number; key: string };

/**
 * Fixed-window per-person governor. It is deliberately independent from the
 * daily IDFM budget: one abusive client cannot starve other clients, and a
 * denied request immediately falls through to the local GTFS planner.
 */
export async function tryConsumePersonalJourneyBudget(
  redis: RedisClient,
  identity: string,
  limit: number,
  windowSeconds: number,
  now: Date
): Promise<PersonalJourneyDecision> {
  const bucket = Math.floor(now.getTime() / 1_000 / windowSeconds);
  const fingerprint = createHash('sha256').update(identity).digest('hex').slice(0, 24);
  const key = `prim:journeys:person:${fingerprint}:${bucket}`;
  try {
    const count = await redis.incr(key);
    if (count === 1) await redis.expire(key, windowSeconds + 60);
    return { allowed: count <= limit, count, key };
  } catch (cause) {
    console.error('[journeys] limite personnelle Redis indisponible', cause);
    return { allowed: false, count: limit + 1, key };
  }
}

import { createHash } from 'node:crypto';

import type { RedisClient } from '../../redis';

export type PersonalBudgetDecision = { allowed: boolean; count: number; key: string };

type PersonalBudgetInput = {
  keyPrefix: string;
  identity: string;
  limit: number;
  windowSeconds: number;
  now: Date;
};

/**
 * Fixed-window per-person governor, shared by every feature that meters an
 * upstream provider per identity. Callers own the key prefix and the fallback
 * policy for a denied request.
 */
export async function tryConsumePersonalBudget(
  redis: RedisClient,
  { keyPrefix, identity, limit, windowSeconds, now }: PersonalBudgetInput
): Promise<PersonalBudgetDecision> {
  const bucket = Math.floor(now.getTime() / 1_000 / windowSeconds);
  const key = `${keyPrefix}:${identityFingerprint(identity)}:${bucket}`;
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, windowSeconds + 60);
  return { allowed: count <= limit, count, key };
}

/**
 * IDFM journey-planning quota. It is deliberately independent from the daily
 * IDFM budget: one abusive client cannot starve other clients, and a denied
 * request immediately falls through to the local GTFS planner.
 */
export function tryConsumePersonalJourneyBudget(
  redis: RedisClient,
  identity: string,
  limit: number,
  windowSeconds: number,
  now: Date
): Promise<PersonalBudgetDecision> {
  return tryConsumePersonalBudget(redis, {
    keyPrefix: 'prim:journeys:person',
    identity,
    limit,
    windowSeconds,
    now,
  });
}

export function identityFingerprint(identity: string) {
  return createHash('sha256').update(identity).digest('hex').slice(0, 24);
}

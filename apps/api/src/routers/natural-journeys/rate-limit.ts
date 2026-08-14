import type { RedisClient } from '../../redis';
import { identityFingerprint, tryConsumePersonalBudget } from '../journeys/rate-limit';

export function consumeNaturalJourneyBudget(
  redis: RedisClient,
  identity: string,
  limit: number,
  windowSeconds: number,
  now: Date
) {
  return tryConsumePersonalBudget(redis, {
    keyPrefix: 'openai:natural-journeys:person',
    identity,
    limit,
    windowSeconds,
    now,
  });
}

export function isInNaturalJourneyRollout(identity: string, percent: number) {
  if (percent <= 0) return false;
  if (percent >= 100) return true;
  const bucket = Number.parseInt(identityFingerprint(identity).slice(0, 8), 16) % 10_000;
  return bucket < Math.round(percent * 100);
}

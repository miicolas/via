import { incrementFixedWindow } from '../http/redis-rate-limit';
import type { RedisClient } from '../redis';
import type { ReportCategory, ReportScopeKind } from './status-resolver';

export type ReportRateLimitReason = 'cooldown' | 'user' | 'ip' | 'unavailable';

export class ReportRateLimitError extends Error {
  constructor(readonly reason: ReportRateLimitReason) {
    super(`Report write rejected: ${reason}`);
  }
}

type LimitInput = {
  userId: string;
  ipHash: string;
  stationId: string;
  category: ReportCategory;
  scopeKind: ReportScopeKind;
  scopeId: string;
};

const HOUR_SECONDS = 60 * 60;

/** Redis is deliberately fail-closed: every check completes before a DB write starts. */
export async function enforceReportWriteLimits(redis: RedisClient, input: LimitInput) {
  try {
    const subject = [input.userId, input.stationId, input.category, input.scopeKind, input.scopeId]
      .map(encodeURIComponent)
      .join(':');
    const claimed = await redis.set(`reports:cooldown:${subject}`, '1', { nx: true, ex: 5 * 60 });
    if (!claimed) throw new ReportRateLimitError('cooldown');

    const userCount = await incrementFixedWindow(
      redis,
      `reports:hour:user:${input.userId}`,
      HOUR_SECONDS
    );
    if (userCount > 10) throw new ReportRateLimitError('user');

    const ipCount = await incrementFixedWindow(
      redis,
      `reports:hour:ip:${input.ipHash}`,
      HOUR_SECONDS
    );
    if (ipCount > 1_000) throw new ReportRateLimitError('ip');
  } catch (error) {
    if (error instanceof ReportRateLimitError) throw error;
    throw new ReportRateLimitError('unavailable');
  }
}

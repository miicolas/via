import { describe, expect, test } from 'bun:test';

import type { RedisClient } from '../redis';
import { ReportRateLimitError, enforceReportWriteLimits } from './rate-limiter';

class FakeRedis {
  values = new Map<string, number | string>();
  fail = false;

  async set(key: string, value: string, options?: { nx?: boolean; ex?: number }) {
    if (this.fail) throw new Error('redis unavailable');
    if (options?.nx && this.values.has(key)) return null;
    this.values.set(key, value);
    return 'OK';
  }

  async incr(key: string) {
    if (this.fail) throw new Error('redis unavailable');
    const value = Number(this.values.get(key) ?? 0) + 1;
    this.values.set(key, value);
    return value;
  }

  async expire() { return 1; }
}

const input = {
  userId: 'user-1',
  ipHash: 'private-hash',
  stationId: 'station-1',
  category: 'crowding' as const,
  scopeKind: 'station' as const,
  scopeId: 'station-1',
};

describe('report write limits', () => {
  test('rejects a second write on the same subject for five minutes', async () => {
    const redis = new FakeRedis() as unknown as RedisClient;
    await enforceReportWriteLimits(redis, input);
    await expect(enforceReportWriteLimits(redis, input)).rejects.toMatchObject({ reason: 'cooldown' });
  });

  test('rejects before PostgreSQL can be touched when Redis is unavailable', async () => {
    const redis = new FakeRedis();
    redis.fail = true;
    await expect(enforceReportWriteLimits(redis as unknown as RedisClient, input))
      .rejects.toBeInstanceOf(ReportRateLimitError);
    await expect(enforceReportWriteLimits(redis as unknown as RedisClient, input))
      .rejects.toMatchObject({ reason: 'unavailable' });
  });

  test('limits a user to ten accepted subjects per hour', async () => {
    const redis = new FakeRedis() as unknown as RedisClient;
    for (let index = 0; index < 10; index += 1) {
      await enforceReportWriteLimits(redis, { ...input, stationId: `station-${index}`, scopeId: `station-${index}` });
    }
    await expect(enforceReportWriteLimits(redis, { ...input, stationId: 'station-11', scopeId: 'station-11' }))
      .rejects.toMatchObject({ reason: 'user' });
  });

  test('keeps the per-IP NAT guard at one thousand writes per hour', async () => {
    const fake = new FakeRedis();
    fake.values.set('reports:hour:ip:private-hash', 1_000);
    await expect(enforceReportWriteLimits(fake as unknown as RedisClient, input))
      .rejects.toMatchObject({ reason: 'ip' });
  });
});

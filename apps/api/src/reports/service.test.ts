import { describe, expect, test } from 'bun:test';

import type { RedisClient } from '../redis';
import { ReportService, type ReportRepository } from './service';
import type { ReportMetric } from './metrics';

function repository(): ReportRepository & { commits: number } {
  return {
    commits: 0,
    async eventExists() { return false; },
    async commit() { this.commits += 1; return 'written' as const; },
    async loadVotes() { return []; },
    async loadStation() {
      return {
        votes: [],
        automaticAccessibility: { condition: 'autonomous' as const, label: 'En autonomie' },
      };
    },
  };
}

function redis(options: { fail?: boolean } = {}) {
  const values = new Map<string, string | number>();
  return {
    async get<T>(key: string) {
      if (options.fail) throw new Error('unavailable');
      const value = values.get(key);
      return value === undefined ? null : value as T;
    },
    async set(key: string, value: string, settings?: { nx?: boolean }) {
      if (options.fail) throw new Error('unavailable');
      if (settings?.nx && values.has(key)) return null;
      values.set(key, value);
      return 'OK';
    },
    async incr(key: string) {
      if (options.fail) throw new Error('unavailable');
      const value = Number(values.get(key) ?? 0) + 1;
      values.set(key, value);
      return value;
    },
    async incrementWithExpiry(key: string, _seconds: number) {
      if (options.fail) throw new Error('unavailable');
      const value = Number(values.get(key) ?? 0) + 1;
      values.set(key, value);
      return value;
    },
    async expire() { return 1; },
  } as unknown as RedisClient;
}

const submission = {
  id: '6eb5b2aa-d316-4617-9003-cbb490e85e0e',
  stationId: 'station-1',
  category: 'wheelchairAccessUnavailable' as const,
  value: 'occurrence' as const,
};

describe('ReportService', () => {
  test('returns an idempotent retry without consuming limits or writing', async () => {
    const store = repository();
    store.eventExists = async () => true;
    const service = new ReportService({ repository: store, redis: redis({ fail: true }), clock: { now: () => new Date('2026-08-23T10:00:00Z') } });

    const status = await service.submit({ userId: 'u1', ipHash: 'h1', submission });
    expect(status.stationId).toBe('station-1');
    expect(store.commits).toBe(0);
  });

  test('does not touch the repository when Redis fails closed', async () => {
    const store = repository();
    const service = new ReportService({ repository: store, redis: redis({ fail: true }), clock: { now: () => new Date('2026-08-23T10:00:00Z') } });

    await expect(service.submit({ userId: 'u1', ipHash: 'h1', submission })).rejects.toMatchObject({ reason: 'unavailable' });
    expect(store.commits).toBe(0);
  });

  test('returns the aggregate containing the newly committed vote', async () => {
    const store = repository();
    store.commit = async (write) => {
      store.commits += 1;
      store.loadStation = async () => ({ votes: [{
        reporterId: write.userId,
        stationId: write.stationId,
        category: write.category,
        scopeKind: write.scopeKind,
        scopeId: write.scopeId,
        value: write.value,
        observedAt: write.observedAt,
      }] });
      return 'written';
    };
    const service = new ReportService({ repository: store, redis: redis(), clock: { now: () => new Date('2026-08-23T10:00:00Z') } });

    const before = await service.stationStatus({ stationId: 'station-1' });
    const status = await service.submit({ userId: 'u1', ipHash: 'h1', submission });
    expect(before.accessibility?.source).toBe('automatic');
    expect(status.accessibility).toMatchObject({ source: 'reported', reporterCount: 1 });
    expect(store.commits).toBe(1);
  });

  test('reads through PostgreSQL when Redis is unavailable', async () => {
    const store = repository();
    const service = new ReportService({ repository: store, redis: redis({ fail: true }), clock: { now: () => new Date('2026-08-23T10:00:00Z') } });
    await expect(service.stationStatus({ stationId: 'station-1' })).resolves.toMatchObject({ stationId: 'station-1' });
  });

  test('metrics expose only aggregate outcomes', async () => {
    const metrics: ReportMetric[] = [];
    const service = new ReportService({
      repository: repository(), redis: redis(),
      clock: { now: () => new Date('2026-08-23T10:00:00Z') },
      recordMetric: (metric) => metrics.push(metric),
    });
    await service.stationStatus({ stationId: 'secret-station' });
    const serialized = JSON.stringify(metrics);
    expect(serialized).not.toContain('secret-station');
    expect(serialized).not.toContain('user');
    expect(metrics[0]).toMatchObject({ operation: 'read', outcome: 'cache-miss' });
  });
});

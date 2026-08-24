import { expect, test } from 'bun:test';
import type { RouteBadge } from '@via/contract';

import { fakeRedis } from './__fixtures__/fake-redis';
import { readCachedStationSnapshot, stationSnapshotThroughCache } from './cache';
import type { NormalizedVisit } from './prim/parse';

const someVisits: NormalizedVisit[] = [
  {
    routeId: 'IDFM:C01371',
    destination: 'La Défense',
    expectedAt: Math.floor(Date.parse('2026-08-12T19:00:00+02:00') / 1_000),
  },
];
const fetchedAt = Math.floor(Date.parse('2026-08-12T18:55:00+02:00') / 1_000);
const routes: RouteBadge[] = [
  {
    id: 'IDFM:C01371',
    shortName: '1',
    mode: 'metro',
    color: '#FFCD00',
    textColor: '#000000',
  },
];
const cacheKey = 'transit:station-snapshot:v1:IDFM:71264';

test('the read-only reader returns a warm snapshot without creating a lock', async () => {
  const { client, store } = fakeRedis();
  store.set(cacheKey, { visits: someVisits, fetchedAt, routes });

  const snapshot = await readCachedStationSnapshot(client, cacheKey);

  expect(snapshot).toEqual({ visits: someVisits, fetchedAt, routes });
  expect(store.has(`${cacheKey}:lock`)).toBe(false);
});

test('the read-only reader turns a miss into null without loading anything', async () => {
  const { client, store } = fakeRedis();

  const snapshot = await readCachedStationSnapshot(client, cacheKey);

  expect(snapshot).toBeNull();
  expect(store.size).toBe(0);
});

test('the read-only reader turns a Redis error into null without creating a lock', async () => {
  const { client, store } = fakeRedis();
  client.get = async () => {
    throw new Error('boom');
  };

  const snapshot = await readCachedStationSnapshot(client, cacheKey);

  expect(snapshot).toBeNull();
  expect(store.has(`${cacheKey}:lock`)).toBe(false);
});

test('a cache hit never reaches the loader', async () => {
  const { client, store } = fakeRedis();
  store.set(cacheKey, { visits: someVisits, fetchedAt, routes });

  let loads = 0;
  const snapshot = await stationSnapshotThroughCache(client, cacheKey, async () => {
    loads += 1;
    return { visits: someVisits, fetchedAt, routes, ttlSeconds: 120 };
  });

  expect(snapshot).toEqual({ visits: someVisits, fetchedAt, routes });
  expect(loads).toBe(0);
});

test('a warm snapshot stays below the 100 ms p95 budget', async () => {
  const { client, store } = fakeRedis();
  store.set(cacheKey, { visits: someVisits, fetchedAt, routes });

  const durations = await Promise.all(
    Array.from({ length: 100 }, async () => {
      const startedAt = performance.now();
      const snapshot = await stationSnapshotThroughCache(client, cacheKey, async () => {
        throw new Error('warm cache unexpectedly loaded');
      });
      expect(snapshot).not.toBeNull();
      return performance.now() - startedAt;
    })
  );

  durations.sort((left, right) => left - right);
  expect(durations[94]).toBeLessThan(100);
});

test('a miss loads once and publishes with the governed TTL', async () => {
  const { client, store, expiries } = fakeRedis();

  const snapshot = await stationSnapshotThroughCache(client, cacheKey, async () => ({
    visits: someVisits,
    fetchedAt,
    routes,
    ttlSeconds: 240,
  }));

  expect(snapshot).toEqual({ visits: someVisits, fetchedAt, routes });
  expect(store.get(cacheKey)).toEqual({ visits: someVisits, fetchedAt, routes });
  expect(expiries.get(cacheKey)).toBe(240);
});

test('100 concurrent misses collapse to a single load', async () => {
  const { client } = fakeRedis();

  let loads = 0;
  const load = async () => {
    loads += 1;
    // Slower than three retry beats, to prove waiters read the published
    // value rather than falling through to a second upstream call.
    await new Promise((resolve) => setTimeout(resolve, 450));
    return { visits: someVisits, fetchedAt, routes, ttlSeconds: 120 };
  };

  const snapshots = await Promise.all(
    Array.from({ length: 100 }, () => stationSnapshotThroughCache(client, cacheKey, load))
  );

  expect(loads).toBe(1);
  expect(snapshots.every((snapshot) => snapshot !== null)).toBe(true);
  expect(snapshots[0]).toEqual({ visits: someVisits, fetchedAt, routes });
});

test('a loader that yields nothing caches nothing and returns null', async () => {
  const { client, store } = fakeRedis();

  const snapshot = await stationSnapshotThroughCache(client, cacheKey, async () => null);

  expect(snapshot).toBeNull();
  expect(store.has(cacheKey)).toBe(false);
});

test('redis failing degrades to null instead of throwing', async () => {
  const { client } = fakeRedis();
  client.get = async () => {
    throw new Error('boom');
  };

  const snapshot = await stationSnapshotThroughCache(client, cacheKey, async () => ({
    visits: someVisits,
    fetchedAt,
    routes,
    ttlSeconds: 120,
  }));

  expect(snapshot).toBeNull();
});

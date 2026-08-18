import { expect, test } from 'bun:test';

import { disruptionsSnapshotThroughCache, type DisruptionsSnapshot } from './snapshot';
import { fakeRedis } from '../../departures/__fixtures__/fake-redis';

const cacheKey = 'transit:line-disruptions:v1';

const someSnapshot: DisruptionsSnapshot = {
  disruptions: [
    {
      id: 'd-blocking',
      severity: 'suspended',
      routeIds: ['IDFM:C01371'],
      periods: [{ beginsAt: 1_000, endsAt: 2_000 }],
      impactedSections: [],
    },
  ],
  fetchedAt: Math.floor(Date.parse('2026-08-18T10:15:00+02:00') / 1_000),
};

test('a cache hit never reaches the loader', async () => {
  const { client, store } = fakeRedis();
  store.set(cacheKey, someSnapshot);

  let loads = 0;
  const snapshot = await disruptionsSnapshotThroughCache(client, async () => {
    loads += 1;
    return someSnapshot;
  });

  expect(snapshot).toEqual(someSnapshot);
  expect(loads).toBe(0);
});

test('a miss loads once and publishes with the snapshot TTL', async () => {
  const { client, store, expiries } = fakeRedis();

  const snapshot = await disruptionsSnapshotThroughCache(client, async () => someSnapshot);

  expect(snapshot).toEqual(someSnapshot);
  expect(store.get(cacheKey)).toEqual(someSnapshot);
  expect(expiries.get(cacheKey)).toBe(120);
});

test('a loader returning null shortens the lock and serves nothing', async () => {
  const { client, store, expiries } = fakeRedis();

  const snapshot = await disruptionsSnapshotThroughCache(client, async () => null);

  expect(snapshot).toBeNull();
  expect(store.has(cacheKey)).toBe(false);
  expect(expiries.get(`${cacheKey}:lock`)).toBe(1);
});

test('a held lock makes the caller wait for the published snapshot', async () => {
  const { client, store } = fakeRedis();
  store.set(`${cacheKey}:lock`, '1');

  const waiting = disruptionsSnapshotThroughCache(client, async () => {
    throw new Error('the waiter must not load');
  });
  setTimeout(() => store.set(cacheKey, someSnapshot), 150);

  expect(await waiting).toEqual(someSnapshot);
});

test('a released lock without a snapshot resolves to null immediately', async () => {
  const { client, store } = fakeRedis();
  store.set(`${cacheKey}:lock`, '1');
  setTimeout(() => store.delete(`${cacheKey}:lock`), 150);

  const snapshot = await disruptionsSnapshotThroughCache(client, async () => {
    throw new Error('the waiter must not load');
  });

  expect(snapshot).toBeNull();
});

test('a corrupt cached value falls through to the loader', async () => {
  const { client, store } = fakeRedis();
  store.set(cacheKey, { disruptions: 'oops', fetchedAt: 'jamais' });

  const snapshot = await disruptionsSnapshotThroughCache(client, async () => someSnapshot);

  expect(snapshot).toEqual(someSnapshot);
});

test('a throwing loader shortens the lock and degrades to null', async () => {
  const { client, expiries } = fakeRedis();

  const snapshot = await disruptionsSnapshotThroughCache(client, async () => {
    throw new Error('PRIM en panne');
  });

  expect(snapshot).toBeNull();
  expect(expiries.get(`${cacheKey}:lock`)).toBe(1);
});

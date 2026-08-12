import { expect, test } from 'bun:test';

import { fakeRedis } from './__fixtures__/fake-redis';
import { visitsThroughCache } from './cache';
import type { NormalizedVisit } from './prim/parse';

const someVisits: NormalizedVisit[] = [
  { routeId: 'IDFM:C01371', destination: 'La Défense', expectedAt: '2026-08-12T19:00:00+02:00' },
];

test('a cache hit never reaches the loader', async () => {
  const { client, store } = fakeRedis();
  store.set('prim:cache:stop:IDFM:71264', someVisits);

  let loads = 0;
  const visits = await visitsThroughCache(client, 'stop:IDFM:71264', async () => {
    loads += 1;
    return { visits: someVisits, ttlSeconds: 120 };
  });

  expect(visits).toEqual(someVisits);
  expect(loads).toBe(0);
});

test('a miss loads once and publishes with the governed TTL', async () => {
  const { client, store, expiries } = fakeRedis();

  const visits = await visitsThroughCache(client, 'stop:IDFM:71264', async () => ({
    visits: someVisits,
    ttlSeconds: 240,
  }));

  expect(visits).toEqual(someVisits);
  expect(store.get('prim:cache:stop:IDFM:71264')).toEqual(someVisits);
  expect(expiries.get('prim:cache:stop:IDFM:71264')).toBe(240);
});

test('concurrent misses collapse to a single load', async () => {
  const { client } = fakeRedis();

  let loads = 0;
  const load = async () => {
    loads += 1;
    // Slower than the loser's retry beat, to prove the loser reads the
    // published value rather than racing a second upstream call.
    await new Promise((resolve) => setTimeout(resolve, 50));
    return { visits: someVisits, ttlSeconds: 120 };
  };

  const [first, second] = await Promise.all([
    visitsThroughCache(client, 'stop:IDFM:71264', load),
    visitsThroughCache(client, 'stop:IDFM:71264', load),
  ]);

  expect(loads).toBe(1);
  expect(first).toEqual(someVisits);
  expect(second).toEqual(someVisits);
});

test('a loader that yields nothing caches nothing and returns null', async () => {
  const { client, store } = fakeRedis();

  const visits = await visitsThroughCache(client, 'stop:IDFM:71264', async () => null);

  expect(visits).toBeNull();
  expect(store.has('prim:cache:stop:IDFM:71264')).toBe(false);
});

test('redis failing degrades to null instead of throwing', async () => {
  const { client } = fakeRedis();
  client.get = async () => {
    throw new Error('boom');
  };

  const visits = await visitsThroughCache(client, 'stop:IDFM:71264', async () => ({
    visits: someVisits,
    ttlSeconds: 120,
  }));

  expect(visits).toBeNull();
});

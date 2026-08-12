import { expect, test } from 'bun:test';

import { fakeRedis } from './__fixtures__/fake-redis';
import { tryConsumeBudget } from './budget';

/** 12:00 in Paris (summer, UTC+2): exactly half the daily prorata elapsed. */
const noonParis = new Date('2026-08-12T10:00:00Z');

test('spending under the ceiling is allowed', async () => {
  const { client } = fakeRedis();

  const decision = await tryConsumeBudget(client, 1000, noonParis);

  expect(decision.allowed).toBe(true);
});

test('the safety reserve denies the last percents of the day', async () => {
  const { client, store } = fakeRedis();
  store.set('prim:budget:stop-monitoring:2026-08-12', 950);

  const decision = await tryConsumeBudget(client, 1000, noonParis);

  expect(decision.allowed).toBe(false);
});

test('the ratio compares consumption to the hour prorata', async () => {
  const { client, store } = fakeRedis();
  store.set('prim:budget:stop-monitoring:2026-08-12', 249);

  // 250th request at noon, when an even spend would sit at 500 → ratio 0.5.
  const decision = await tryConsumeBudget(client, 1000, noonParis);

  expect(decision.ratio).toBeCloseTo(0.5, 2);
});

test('the day key follows Paris, not UTC', async () => {
  const { client, store } = fakeRedis();

  // 23:30 UTC on the 12th is already the 13th in Paris.
  await tryConsumeBudget(client, 1000, new Date('2026-08-12T23:30:00Z'));

  expect([...store.keys()]).toContain('prim:budget:stop-monitoring:2026-08-13');
});

test('redis failing denies rather than risking the quota', async () => {
  const { client } = fakeRedis();
  client.incr = async () => {
    throw new Error('boom');
  };

  const decision = await tryConsumeBudget(client, 1000, noonParis);

  expect(decision.allowed).toBe(false);
});

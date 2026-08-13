import { expect, test } from 'bun:test';

import { fakeRedis } from '../departures/__fixtures__/fake-redis';
import { valueThroughCache } from './cache';

test('concurrent journey misses share one upstream calculation', async () => {
  const { client } = fakeRedis();
  let loads = 0;
  const load = async () => {
    loads += 1;
    await new Promise((resolve) => setTimeout(resolve, 120));
    return { value: { status: 'ready' }, ttlSeconds: 30 };
  };

  const [first, second] = await Promise.all([
    valueThroughCache(client, 'same-trip', load),
    valueThroughCache(client, 'same-trip', load),
  ]);

  expect(loads).toBe(1);
  expect(first).toEqual({ status: 'ready' });
  expect(second).toEqual(first);
});

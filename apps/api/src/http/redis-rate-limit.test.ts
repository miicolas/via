import { describe, expect, test } from 'bun:test';

import type { RedisClient } from '../redis';
import { fakeRedis } from '../routers/departures/__fixtures__/fake-redis';
import { incrementFixedWindow } from './redis-rate-limit';

function incrementOnlyFake(options: {
  counts?: number[];
  error?: Error;
} = {}) {
  const calls: Array<{ key: string; seconds: number }> = [];
  let index = 0;
  const client = {
    async incrementWithExpiry(key: string, seconds: number) {
      calls.push({ key, seconds });
      if (options.error) throw options.error;
      return options.counts?.[index++] ?? index;
    },
  } as Pick<RedisClient, 'incrementWithExpiry'>;
  return { client, calls };
}

describe('incrementFixedWindow', () => {
  test('uses one atomic call for the first and second hit', async () => {
    const { client, calls } = incrementOnlyFake({ counts: [1, 2] });

    await expect(incrementFixedWindow(client as RedisClient, 'quota:key', 60)).resolves.toBe(1);
    await expect(incrementFixedWindow(client as RedisClient, 'quota:key', 60)).resolves.toBe(2);

    expect(calls).toEqual([
      { key: 'quota:key', seconds: 60 },
      { key: 'quota:key', seconds: 60 },
    ]);
  });

  test('propagates an atomic Redis failure', async () => {
    const failure = new Error('redis unavailable');
    const { client, calls } = incrementOnlyFake({ error: failure });

    await expect(incrementFixedWindow(client as RedisClient, 'quota:key', 60)).rejects.toBe(failure);
    expect(calls).toEqual([{ key: 'quota:key', seconds: 60 }]);
  });

  test('repairs an orphaned key without renewing an existing window', async () => {
    const { client, store, expiries } = fakeRedis();

    await incrementFixedWindow(client, 'quota:key', 60);
    expect(expiries.get('quota:key')).toBe(60);

    expiries.delete('quota:key');
    await incrementFixedWindow(client, 'quota:key', 120);
    expect(expiries.get('quota:key')).toBe(120);

    await incrementFixedWindow(client, 'quota:key', 300);
    expect(expiries.get('quota:key')).toBe(120);
    expect(store.get('quota:key')).toBe(3);
  });

  test.each([0, -1, 1.5, Number.NaN, Number.POSITIVE_INFINITY])(
    'rejects an invalid window (%s) before accessing Redis',
    async (seconds) => {
      const { client, calls } = incrementOnlyFake();

      await expect(incrementFixedWindow(client as RedisClient, 'quota:key', seconds)).rejects.toThrow(
        'positive integer duration',
      );
      expect(calls).toHaveLength(0);
    },
  );
});

import type { RedisClient } from '../../../redis';

/**
 * In-memory stand-in for the Redis client, close enough for the cache and
 * budget tests: honors `nx`, records every `ex` it sees, ignores real time
 * (tests expire keys by deleting them).
 */
export function fakeRedis() {
  const store = new Map<string, unknown>();
  const expiries = new Map<string, number>();

  const client: RedisClient = {
    get: (async (key: string) => store.get(key) ?? null) as RedisClient['get'],
    set: (async (key: string, value: unknown, opts?: { nx?: boolean; ex?: number }) => {
      if (opts?.nx && store.has(key)) return null;
      // Redis stores strings; mirror the production adapter's JSON round-trip
      // while keeping the fixture convenient to inspect in tests.
      store.set(key, typeof value === 'string' ? JSON.parse(value) : value);
      if (opts?.ex !== undefined) expiries.set(key, opts.ex);
      return 'OK';
    }) as RedisClient['set'],
    incr: (async (key: string) => {
      const next = ((store.get(key) as number) ?? 0) + 1;
      store.set(key, next);
      return next;
    }) as RedisClient['incr'],
    expire: (async (key: string, seconds: number) => {
      expiries.set(key, seconds);
      return 1;
    }) as RedisClient['expire'],
    del: (async (key: string) => {
      const existed = store.delete(key);
      expiries.delete(key);
      return existed ? 1 : 0;
    }) as RedisClient['del'],
  };

  return { client, store, expiries };
}

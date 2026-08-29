import type { RedisClient } from "../../../redis";

/**
 * In-memory stand-in for the Redis client, close enough for the cache and
 * budget tests: honors `nx`, records every `ex` it sees, ignores real time
 * (tests expire keys by deleting them).
 */
export function fakeRedis() {
  const store = new Map<string, unknown>();
  const expiries = new Map<string, number>();

  const client: RedisClient = {
    get: (async (key: string) => store.get(key) ?? null) as RedisClient["get"],
    set: (async (
      key: string,
      value: unknown,
      opts?: { nx?: boolean; ex?: number },
    ) => {
      if (opts?.nx && store.has(key)) return null;
      // Redis stores strings; mirror the production adapter's JSON round-trip
      // while keeping the fixture convenient to inspect in tests.
      store.set(key, typeof value === "string" ? JSON.parse(value) : value);
      if (opts?.ex !== undefined) expiries.set(key, opts.ex);
      return "OK";
    }) as RedisClient["set"],
    incr: (async (key: string) => {
      const next = ((store.get(key) as number) ?? 0) + 1;
      store.set(key, next);
      return next;
    }) as RedisClient["incr"],
    expire: (async (key: string, seconds: number) => {
      expiries.set(key, seconds);
      return 1;
    }) as RedisClient["expire"],
    incrementWithExpiry: (async (key: string, seconds: number) => {
      const next = ((store.get(key) as number) ?? 0) + 1;
      store.set(key, next);
      // A fixed window starts at creation. If a legacy key has lost its TTL,
      // repair it once; never move an existing window's deadline.
      if (!expiries.has(key)) expiries.set(key, seconds);
      return next;
    }) as RedisClient["incrementWithExpiry"],
    del: (async (key: string) => {
      const existed = store.delete(key);
      expiries.delete(key);
      return existed ? 1 : 0;
    }) as RedisClient["del"],
    compareAndExpire: (async (
      key: string,
      expectedValue: string,
      seconds: number,
    ) => {
      if (store.get(key) !== JSON.parse(expectedValue)) return false;
      expiries.set(key, seconds);
      return true;
    }) as RedisClient["compareAndExpire"],
    compareAndDelete: (async (key: string, expectedValue: string) => {
      if (store.get(key) !== JSON.parse(expectedValue)) return false;
      store.delete(key);
      expiries.delete(key);
      return true;
    }) as RedisClient["compareAndDelete"],
    claimNotification: (async (
      input: Parameters<RedisClient["claimNotification"]>[0],
    ) => {
      const expected = JSON.parse(input.expectedVersion);
      const current = store.get(input.versionKey);
      if (current !== undefined && current !== expected) return "stale";
      if (current === undefined) {
        store.set(input.versionKey, expected);
        expiries.set(input.versionKey, input.versionTTLSeconds);
      }
      if (
        store.has(input.deliveredKey) ||
        store.has(input.claimKey) ||
        store.has(input.leaseKey)
      ) {
        return "duplicate";
      }
      store.set(input.claimKey, JSON.parse(input.claimValue));
      expiries.set(input.claimKey, input.claimTTLSeconds);
      store.set(input.leaseKey, JSON.parse(input.leaseValue));
      expiries.set(input.leaseKey, input.leaseTTLSeconds);
      return "claimed";
    }) as RedisClient["claimNotification"],
    setSubscriptionVersionWhenIdle: (async (
      input: Parameters<RedisClient["setSubscriptionVersionWhenIdle"]>[0],
    ) => {
      if (store.has(input.leaseKey)) return false;
      store.set(input.versionKey, JSON.parse(input.value));
      expiries.set(input.versionKey, input.ttlSeconds);
      return true;
    }) as RedisClient["setSubscriptionVersionWhenIdle"],
  };

  return { client, store, expiries };
}

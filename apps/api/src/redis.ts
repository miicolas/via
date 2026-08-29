import { RedisClient as BunRedisClient } from "bun";

import { env } from "./env";

type SetOptions = {
  nx?: boolean;
  ex?: number;
};

/**
 * The small Redis surface the API needs — also the seam tests fake.
 * Values are JSON in the cache, so the adapter keeps the typed read used by
 * the cache module while the native Bun client deals in Redis strings.
 */
export type RedisClient = {
  get: <T>(key: string) => Promise<T | null>;
  set: (
    key: string,
    value: string,
    options?: SetOptions,
  ) => Promise<string | null>;
  incr: (key: string) => Promise<number>;
  expire: (key: string, seconds: number) => Promise<number>;
  /** Increment a fixed-window counter and repair its TTL atomically. */
  incrementWithExpiry: (key: string, seconds: number) => Promise<number>;
  del: (key: string) => Promise<number>;
  compareAndExpire: (
    key: string,
    expectedValue: string,
    seconds: number,
  ) => Promise<boolean>;
  compareAndDelete: (key: string, expectedValue: string) => Promise<boolean>;
  claimNotification: (input: {
    versionKey: string;
    expectedVersion: string;
    versionTTLSeconds: number;
    deliveredKey: string;
    claimKey: string;
    claimValue: string;
    claimTTLSeconds: number;
    leaseKey: string;
    leaseValue: string;
    leaseTTLSeconds: number;
  }) => Promise<"claimed" | "duplicate" | "stale">;
  setSubscriptionVersionWhenIdle: (input: {
    versionKey: string;
    leaseKey: string;
    value: string;
    ttlSeconds: number;
  }) => Promise<boolean>;
};

/**
 * Bun opens the connection lazily on the first command and reconnects when the
 * local container is restarted. Redis failures are still handled by the cache
 * and quota layers, which fall back to the theoretical schedule.
 */
const client = new BunRedisClient(env.REDIS_URL);

export const redis: RedisClient = {
  get: async <T>(key: string) => {
    const value = await client.get(key);
    return value === null ? null : (JSON.parse(value) as T);
  },
  set: (key, value, options) => {
    if (options?.nx && options.ex !== undefined) {
      return client.set(key, value, "EX", String(options.ex), "NX");
    }
    if (options?.nx) return client.set(key, value, "NX");
    if (options?.ex !== undefined)
      return client.set(key, value, "EX", String(options.ex));
    return client.set(key, value);
  },
  incr: (key) => client.incr(key),
  expire: (key, seconds) => client.expire(key, seconds),
  incrementWithExpiry: async (key, seconds) => {
    const result = await client.send("EVAL", [
      "local count = redis.call('INCR', KEYS[1]); local ttl = redis.call('TTL', KEYS[1]); if ttl == -1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end; return count",
      "1",
      key,
      String(seconds),
    ]);
    return Number(result);
  },
  del: (key) => client.del(key),
  compareAndExpire: async (key, expectedValue, seconds) => {
    const result = await client.send("EVAL", [
      "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('EXPIRE', KEYS[1], ARGV[2]) else return 0 end",
      "1",
      key,
      expectedValue,
      String(seconds),
    ]);
    return Number(result) === 1;
  },
  compareAndDelete: async (key, expectedValue) => {
    const result = await client.send("EVAL", [
      "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) else return 0 end",
      "1",
      key,
      expectedValue,
    ]);
    return Number(result) === 1;
  },
  claimNotification: async (input) => {
    const result = await client.send("EVAL", [
      "local current = redis.call('GET', KEYS[1]); if current and current ~= ARGV[1] then return -1 end; if not current then redis.call('SET', KEYS[1], ARGV[1], 'EX', ARGV[2]) end; if redis.call('EXISTS', KEYS[2]) == 1 or redis.call('EXISTS', KEYS[3]) == 1 or redis.call('EXISTS', KEYS[4]) == 1 then return 0 end; redis.call('SET', KEYS[3], ARGV[3], 'EX', ARGV[4]); redis.call('SET', KEYS[4], ARGV[5], 'EX', ARGV[6]); return 1",
      "4",
      input.versionKey,
      input.deliveredKey,
      input.claimKey,
      input.leaseKey,
      input.expectedVersion,
      String(input.versionTTLSeconds),
      input.claimValue,
      String(input.claimTTLSeconds),
      input.leaseValue,
      String(input.leaseTTLSeconds),
    ]);
    if (Number(result) === 1) return "claimed";
    if (Number(result) === -1) return "stale";
    return "duplicate";
  },
  setSubscriptionVersionWhenIdle: async (input) => {
    const result = await client.send("EVAL", [
      "if redis.call('EXISTS', KEYS[2]) == 1 then return 0 end; redis.call('SET', KEYS[1], ARGV[1], 'EX', ARGV[2]); return 1",
      "2",
      input.versionKey,
      input.leaseKey,
      input.value,
      String(input.ttlSeconds),
    ]);
    return Number(result) === 1;
  },
};

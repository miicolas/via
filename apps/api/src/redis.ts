import { RedisClient as BunRedisClient } from 'bun';

import { env } from './env';

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
  set: (key: string, value: string, options?: SetOptions) => Promise<string | null>;
  incr: (key: string) => Promise<number>;
  expire: (key: string, seconds: number) => Promise<number>;
  del: (key: string) => Promise<number>;
  compareAndExpire: (key: string, expectedValue: string, seconds: number) => Promise<boolean>;
  compareAndDelete: (key: string, expectedValue: string) => Promise<boolean>;
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
      return client.set(key, value, 'EX', String(options.ex), 'NX');
    }
    if (options?.nx) return client.set(key, value, 'NX');
    if (options?.ex !== undefined) return client.set(key, value, 'EX', String(options.ex));
    return client.set(key, value);
  },
  incr: (key) => client.incr(key),
  expire: (key, seconds) => client.expire(key, seconds),
  del: (key) => client.del(key),
  compareAndExpire: async (key, expectedValue, seconds) => {
    const result = await client.send('EVAL', [
      "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('EXPIRE', KEYS[1], ARGV[2]) else return 0 end",
      '1',
      key,
      expectedValue,
      String(seconds),
    ]);
    return Number(result) === 1;
  },
  compareAndDelete: async (key, expectedValue) => {
    const result = await client.send('EVAL', [
      "if redis.call('GET', KEYS[1]) == ARGV[1] then return redis.call('DEL', KEYS[1]) else return 0 end",
      '1',
      key,
      expectedValue,
    ]);
    return Number(result) === 1;
  },
};

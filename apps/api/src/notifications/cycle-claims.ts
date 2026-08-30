import type { RedisClient } from "../redis";

/**
 * Coordination backend for a notification cycle. Every operation is keyed by a
 * caller-owned name, so the store stays ignorant of what a unit of work is:
 * `claim`/`release` cover cycle-shard ownership and delivery dedup alike, and
 * `isSet`/`set` back the shared circuit-breaker flag.
 *
 * The occurrence dispatcher's claim is deliberately not behind this interface:
 * its database claim returns the claimed work rows themselves (with badge and
 * daily-cap counts) rather than a boolean on a name, so it stays its own
 * adapter (`NotificationOccurrenceStore.claimDue`) behind the same cycle.
 */
export interface NotificationCycleClaimStore {
  /** Atomically claims `key` for `ttlSeconds`; false when another worker holds it. */
  claim(key: string, ttlSeconds: number): Promise<boolean>;
  /** Releases a claim so a later cycle can retry. Never throws. */
  release(key: string): Promise<void>;
  /** True when the flag at `key` is currently raised. */
  isSet(key: string): Promise<boolean>;
  /** Raises the flag at `key` for `ttlSeconds`, overwriting any holder. */
  set(key: string, ttlSeconds: number): Promise<void>;
}

export function createRedisNotificationCycleClaims(
  redis: RedisClient,
): NotificationCycleClaimStore {
  return {
    async claim(key, ttlSeconds) {
      return (
        (await redis.set(key, "1", { nx: true, ex: ttlSeconds })) !== null
      );
    },
    async release(key) {
      await redis.del(key).catch(() => undefined);
    },
    async isSet(key) {
      return (await redis.get(key)) !== null;
    },
    async set(key, ttlSeconds) {
      await redis.set(key, "1", { ex: ttlSeconds });
    },
  };
}

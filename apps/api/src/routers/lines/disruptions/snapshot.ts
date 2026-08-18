import { fetchDisruptionsBulk } from './client';
import { parseDisruptionsBulk, type NormalizedDisruption } from './parse';
import { env } from '../../../env';
import type { RedisClient } from '../../../redis';
import { tryConsumeDailyIdfmBudget } from '../../idfm/daily-budget';

const CACHE_KEY = 'transit:line-disruptions:v1';
const BUDGET_KEY_PREFIX = 'transit:line-disruptions:idfm-budget';

/** One network-wide fetch per window; disruptions move at minute scale. */
const SNAPSHOT_TTL_SECONDS = 120;

// Covers the 15 s bulk timeout plus parse and Redis round-trips, so a slow
// miss cannot reopen the single-flight window.
const LOCK_TTL_SECONDS = 20;
// Waiters give up long before the lock does: an HTTP handler would rather
// degrade than sit on a cold cache for the whole bulk round-trip.
const WAIT_DEADLINE_MS = 5_000;
const LOCK_RETRY_DELAY_MS = 100;

export type DisruptionsSnapshot = {
  disruptions: NormalizedDisruption[];
  /** Epoch seconds at which the API fetched the upstream payload. */
  fetchedAt: number;
};

/**
 * The network-wide disruptions snapshot, refreshed through the shared cache.
 * `null` means "nothing servable right now" — Redis down, budget exhausted, or
 * PRIM unavailable on a cold cache; the caller decides what that costs.
 */
export async function getDisruptionsSnapshot(
  redis: RedisClient,
  now: Date
): Promise<DisruptionsSnapshot | null> {
  return disruptionsSnapshotThroughCache(redis, async () => {
    const { allowed, ratio } = await tryConsumeDailyIdfmBudget(redis, {
      dailyBudget: env.PRIM_DISRUPTIONS_DAILY_BUDGET,
      now,
      counterKeyPrefix: BUDGET_KEY_PREFIX,
    });
    if (!allowed) {
      console.error(`[lines] budget PRIM disruptions épuisé (ratio ${ratio.toFixed(2)})`);
      return null;
    }

    const body = await fetchDisruptionsBulk();
    if (body === null) return null;

    return {
      disruptions: parseDisruptionsBulk(body),
      fetchedAt: Math.floor(now.getTime() / 1_000),
    };
  });
}

type LoadFresh = () => Promise<DisruptionsSnapshot | null>;

/**
 * Read-through cache with a best-effort cross-instance single-flight, the
 * departures pattern applied to one global key. Cache hit → serve it. Miss →
 * take a short `SET NX` lock; the winner calls `loadFresh` and publishes,
 * losers briefly wait and re-read what the winner published. Every failure
 * path collapses to `null`.
 */
export async function disruptionsSnapshotThroughCache(
  redis: RedisClient,
  loadFresh: LoadFresh
): Promise<DisruptionsSnapshot | null> {
  try {
    const cached = await readSnapshot(redis);
    if (cached) return cached;

    const lock = await redis.set(`${CACHE_KEY}:lock`, '1', {
      nx: true,
      ex: LOCK_TTL_SECONDS,
    });
    if (lock === null) return await waitForPublishedSnapshot(redis);

    let fresh: DisruptionsSnapshot | null;
    try {
      fresh = await loadFresh();
    } catch (cause) {
      // Do not make waiters sit on the full lock TTL after an upstream error.
      await redis.expire(`${CACHE_KEY}:lock`, 1).catch(() => undefined);
      throw cause;
    }
    if (!fresh) {
      await redis.expire(`${CACHE_KEY}:lock`, 1).catch(() => undefined);
      return null;
    }

    await redis.set(CACHE_KEY, JSON.stringify(fresh), { ex: SNAPSHOT_TTL_SECONDS });
    return fresh;
  } catch (cause) {
    await redis.expire(`${CACHE_KEY}:lock`, 1).catch(() => undefined);
    console.error('[lines] cache Redis indisponible', cause);
    return null;
  }
}

async function waitForPublishedSnapshot(redis: RedisClient): Promise<DisruptionsSnapshot | null> {
  const deadline = Date.now() + WAIT_DEADLINE_MS;

  while (Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, LOCK_RETRY_DELAY_MS));

    const cached = await readSnapshot(redis);
    if (cached) return cached;

    // A failed winner shortens the lock to one second. Once it expires, fall
    // back immediately instead of making every waiter burn the whole window.
    if ((await redis.get<unknown>(`${CACHE_KEY}:lock`)) === null) return null;
  }
  return null;
}

async function readSnapshot(redis: RedisClient): Promise<DisruptionsSnapshot | null> {
  const cached = await redis.get<unknown>(CACHE_KEY);
  if (!cached || typeof cached !== 'object' || Array.isArray(cached)) return null;

  const candidate = cached as { disruptions?: unknown; fetchedAt?: unknown };
  if (
    !Array.isArray(candidate.disruptions) ||
    typeof candidate.fetchedAt !== 'number' ||
    !Number.isFinite(candidate.fetchedAt)
  ) {
    return null;
  }

  return {
    disruptions: candidate.disruptions as NormalizedDisruption[],
    fetchedAt: candidate.fetchedAt,
  } satisfies DisruptionsSnapshot;
}

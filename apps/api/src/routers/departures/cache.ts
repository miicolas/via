import type { NormalizedVisit } from './prim/parse';
import type { RouteBadge } from '@via/contract';
import type { RedisClient } from '../../redis';

// PRIM is capped at 2 s; the extra headroom covers the route lookup and Redis
// round-trip so a slow miss cannot reopen the single-flight window.
const LOCK_TTL_SECONDS = 5;
const LOCK_RETRY_DELAY_MS = 100;

export type CachedStationSnapshot = {
  visits: NormalizedVisit[];
  /** Epoch seconds at which the API fetched the upstream payload. */
  fetchedAt: number;
  /** The GTFS-derived badges used to render the snapshot. */
  routes: RouteBadge[];
};

type LoadFresh = () => Promise<(CachedStationSnapshot & { ttlSeconds: number }) | null>;

/**
 * Reads an already-published departure snapshot without ever filling it.
 * A miss or Redis outage is deliberately indistinguishable to passive callers:
 * neither is allowed to acquire the cache lock or spend Stop Monitoring quota.
 */
export async function readCachedStationSnapshot(
  redis: RedisClient,
  cacheKey: string,
): Promise<CachedStationSnapshot | null> {
  try {
    return await readSnapshot(redis, cacheKey);
  } catch (cause) {
    console.error('[departures] cached snapshot unavailable', cause);
    return null;
  }
}

/**
 * Read-through cache with a best-effort cross-instance single-flight.
 *
 * Cache hit → serve it. Miss → take a short `SET NX` lock; the winner calls
 * `loadFresh` (budget check + PRIM round-trip) and publishes the result, losers
 * wait for the bounded request and re-read what the winner published. Every failure path —
 * Redis down, lock contention with nothing published, `loadFresh` returning
 * null — collapses to `null`, which the handler turns into its fallback. N
 * concurrent viewers of one station therefore cost ~1 PRIM request, and never
 * an error.
 */
export async function stationSnapshotThroughCache(
  redis: RedisClient,
  cacheKey: string,
  loadFresh: LoadFresh
): Promise<CachedStationSnapshot | null> {
  try {
    const cached = await readSnapshot(redis, cacheKey);
    if (cached) return cached;

    const lock = await redis.set(`${cacheKey}:lock`, '1', {
      nx: true,
      ex: LOCK_TTL_SECONDS,
    });

    if (lock === null) {
      // Another instance is fetching: wait for its bounded PRIM request to
      // publish the snapshot. Plain setTimeout, not Bun.sleep — Vercel runs
      // this on Node.
      return await waitForPublishedSnapshot(redis, cacheKey);
    }

    let fresh: (CachedStationSnapshot & { ttlSeconds: number }) | null;
    try {
      fresh = await loadFresh();
    } catch (cause) {
      // Do not make waiters sit on the full lock TTL after an upstream error.
      await redis.expire(`${cacheKey}:lock`, 1).catch(() => undefined);
      throw cause;
    }
    if (!fresh) {
      await redis.expire(`${cacheKey}:lock`, 1).catch(() => undefined);
      return null;
    }

    await redis.set(cacheKey, JSON.stringify({
      visits: fresh.visits,
      fetchedAt: fresh.fetchedAt,
      routes: fresh.routes,
    }), {
      ex: fresh.ttlSeconds,
    });
    return {
      visits: fresh.visits,
      fetchedAt: fresh.fetchedAt,
      routes: fresh.routes,
    };
  } catch (cause) {
    await redis.expire(`${cacheKey}:lock`, 1).catch(() => undefined);
    console.error('[departures] cache Redis indisponible', cause);
    return null;
  }
}

async function waitForPublishedSnapshot(
  redis: RedisClient,
  cacheKey: string
): Promise<CachedStationSnapshot | null> {
  const deadline = Date.now() + LOCK_TTL_SECONDS * 1_000;
  const lockKey = `${cacheKey}:lock`;

  while (Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, LOCK_RETRY_DELAY_MS));

    const cached = await readSnapshot(redis, cacheKey);
    if (cached) return cached;

    // A failed winner shortens the lock to one second. Once it expires, fall
    // back immediately instead of making every waiter burn the whole window.
    if ((await redis.get<unknown>(lockKey)) === null) return null;
  }

  return null;
}

async function readSnapshot(redis: RedisClient, cacheKey: string) {
  const cached = await redis.get<unknown>(cacheKey);
  if (!cached || typeof cached !== 'object' || Array.isArray(cached)) return null;

  const candidate = cached as { visits?: unknown; fetchedAt?: unknown; routes?: unknown };
  if (
    !Array.isArray(candidate.visits) ||
    typeof candidate.fetchedAt !== 'number' ||
    !Number.isFinite(candidate.fetchedAt) ||
    !Array.isArray(candidate.routes) ||
    candidate.routes.length === 0
  ) {
    return null;
  }

  return {
    visits: candidate.visits as NormalizedVisit[],
    fetchedAt: candidate.fetchedAt,
    routes: candidate.routes as RouteBadge[],
  } satisfies CachedStationSnapshot;
}

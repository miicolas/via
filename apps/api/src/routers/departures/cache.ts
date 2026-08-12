import type { NormalizedVisit } from './prim/parse';
import type { RedisClient } from '../../redis';

const LOCK_TTL_SECONDS = 3;
const LOCK_RETRY_DELAY_MS = 300;

type LoadFresh = () => Promise<{ visits: NormalizedVisit[]; ttlSeconds: number } | null>;

/**
 * Read-through cache with a best-effort cross-instance single-flight.
 *
 * Cache hit → serve it. Miss → take a short `SET NX` lock; the winner calls
 * `loadFresh` (budget check + PRIM round-trip) and publishes the result, losers
 * wait one beat and re-read what the winner published. Every failure path —
 * Redis down, lock contention with nothing published, `loadFresh` returning
 * null — collapses to `null`, which the handler turns into its fallback. N
 * concurrent viewers of one station therefore cost ~1 PRIM request, and never
 * an error.
 */
export async function visitsThroughCache(
  redis: RedisClient,
  cacheKey: string,
  loadFresh: LoadFresh
): Promise<NormalizedVisit[] | null> {
  try {
    const cached = await readVisits(redis, cacheKey);
    if (cached) return cached;

    const lock = await redis.set(`prim:lock:${cacheKey}`, '1', {
      nx: true,
      ex: LOCK_TTL_SECONDS,
    });

    if (lock === null) {
      // Another instance is fetching: give it one beat, then take its result.
      // Plain setTimeout, not Bun.sleep — Vercel runs this on Node.
      await new Promise((resolve) => setTimeout(resolve, LOCK_RETRY_DELAY_MS));
      return await readVisits(redis, cacheKey);
    }

    const fresh = await loadFresh();
    if (!fresh) return null;

    await redis.set(`prim:cache:${cacheKey}`, JSON.stringify(fresh.visits), {
      ex: fresh.ttlSeconds,
    });
    return fresh.visits;
  } catch (cause) {
    console.error('[departures] cache Redis indisponible', cause);
    return null;
  }
}

async function readVisits(redis: RedisClient, cacheKey: string) {
  const cached = await redis.get<NormalizedVisit[]>(`prim:cache:${cacheKey}`);
  return cached ?? null;
}

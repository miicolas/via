import type { RedisClient } from '../../redis';

const LOCK_TTL_SECONDS = 5;
const LOCK_RETRY_DELAY_MS = 50;

type LoadFresh<T> = () => Promise<{ value: T; ttlSeconds: number } | null>;

/** Generic read-through cache used by the journey seam. */
export async function valueThroughCache<T>(
  redis: RedisClient,
  cacheKey: string,
  loadFresh: LoadFresh<T>
): Promise<T | null> {
  try {
    const cached = await redis.get<T>(`journeys:cache:${cacheKey}`);
    if (cached !== null) return cached;

    const lock = await redis.set(`journeys:lock:${cacheKey}`, '1', {
      nx: true,
      ex: LOCK_TTL_SECONDS,
    });
    if (lock === null) {
      return waitForPublishedValue<T>(redis, cacheKey);
    }

    const fresh = await loadFresh();
    if (!fresh) return null;
    await redis.set(`journeys:cache:${cacheKey}`, JSON.stringify(fresh.value), {
      ex: fresh.ttlSeconds,
    });
    return fresh.value;
  } catch (cause) {
    console.error('[journeys] cache Redis indisponible', cause);
    return null;
  }
}

async function waitForPublishedValue<T>(redis: RedisClient, cacheKey: string) {
  const deadline = Date.now() + LOCK_TTL_SECONDS * 1_000;
  while (Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, LOCK_RETRY_DELAY_MS));
    const cached = await redis.get<T>(`journeys:cache:${cacheKey}`);
    if (cached !== null) return cached;
  }
  return null;
}

export function journeyCacheKey(input: {
  origin: { latitude: number; longitude: number };
  destination: { id: string; coordinate: { latitude: number; longitude: number } };
  limit: number;
  requestedAt: Date;
  datetimeRepresents?: 'departure' | 'arrival';
  requiredModes?: string[];
  excludedModes?: string[];
  preferredModes?: string[];
}) {
  const round = (value: number) => Math.round(value * 10_000) / 10_000;
  const minute = Math.floor(input.requestedAt.getTime() / 60_000);
  return [
    round(input.origin.latitude),
    round(input.origin.longitude),
    input.destination.id,
    round(input.destination.coordinate.latitude),
    round(input.destination.coordinate.longitude),
    input.limit,
    minute,
    input.datetimeRepresents ?? 'departure',
    [...(input.requiredModes ?? [])].sort().join(','),
    [...(input.excludedModes ?? [])].sort().join(','),
    [...(input.preferredModes ?? [])].sort().join(','),
  ].join(':');
}

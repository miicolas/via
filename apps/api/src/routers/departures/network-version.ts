import type { RedisClient } from '../../redis';

const NETWORK_VERSION_KEY = 'transit:network:version';
const FALLBACK_VERSION = '1';
const LOCAL_VERSION_TTL_MS = 60_000;

let localVersion: { value: string; expiresAt: number } | undefined;

/**
 * Keeps station metadata keys versioned across a GTFS import without making
 * every request hit Postgres. The importer increments the shared Redis value;
 * each API instance refreshes its local copy at most once per minute.
 */
export async function transitNetworkCacheVersion(redis: RedisClient): Promise<string> {
  const now = Date.now();
  if (localVersion && localVersion.expiresAt > now) return localVersion.value;

  let version = FALLBACK_VERSION;
  try {
    const value = await redis.get<unknown>(NETWORK_VERSION_KEY);
    if (typeof value === 'number' || typeof value === 'string') version = String(value);
  } catch (cause) {
    console.error('[departures] transit network version unavailable', cause);
  }
  localVersion = { value: version, expiresAt: now + LOCAL_VERSION_TTL_MS };
  return version;
}

export const transitNetworkVersionKey = NETWORK_VERSION_KEY;

export function transitStationSnapshotCacheKey(version: string, stationId: string): string {
  return `transit:station-snapshot:v${version}:${stationId}`;
}

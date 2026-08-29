import { importMeta, db } from '@via/db';
import { eq } from 'drizzle-orm';

const NETWORK_VERSION_KEY = 'transit:network:version';
const FALLBACK_VERSION = '1';
const LOCAL_VERSION_TTL_MS = 60_000;

export type TransitNetworkVersionReader = () => Promise<string>;

type VersionReaderOptions = {
  read: () => Promise<unknown>;
  now?: () => number;
  ttlMs?: number;
  onUnavailable?: () => void;
};

/**
 * Keep the last durable generation in memory for one minute. During a database
 * outage, stale is safer than inventing a new namespace: the existing cache
 * remains coherent and retries are throttled by the same local TTL.
 */
export function createTransitNetworkVersionReader({
  read,
  now = () => Date.now(),
  ttlMs = LOCAL_VERSION_TTL_MS,
  onUnavailable = () => {
    console.error('[departures] transit network version unavailable');
  },
}: VersionReaderOptions): TransitNetworkVersionReader {
  let localVersion: { value: string; expiresAt: number } | undefined;

  return async () => {
    const currentTime = now();
    if (localVersion && localVersion.expiresAt > currentTime) return localVersion.value;

    try {
      const value = await read();
      const version =
        typeof value === 'number' || typeof value === 'string'
          ? String(value)
          : FALLBACK_VERSION;
      localVersion = { value: version, expiresAt: currentTime + ttlMs };
      return version;
    } catch {
      onUnavailable();
      const value = localVersion?.value ?? FALLBACK_VERSION;
      localVersion = { value, expiresAt: currentTime + ttlMs };
      return value;
    }
  };
}

const productionReader = createTransitNetworkVersionReader({
  read: async () => {
    const [row] = await db
      .select({ value: importMeta.value })
      .from(importMeta)
      .where(eq(importMeta.key, NETWORK_VERSION_KEY));
    return row?.value ?? null;
  },
});

export function transitNetworkCacheVersion(): Promise<string> {
  return productionReader();
}

export const transitNetworkVersionKey = NETWORK_VERSION_KEY;

export function transitStationSnapshotCacheKey(version: string, stationId: string): string {
  return `transit:station-snapshot:v${version}:${stationId}`;
}

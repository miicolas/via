import type {
  SharedMobilityItem,
  SharedMobilityProvider,
  SharedMobilitySourceStatus,
} from '@via/contract';

import { fetchSharedMobilityProvider } from './client';

const PROVIDERS: SharedMobilityProvider[] = ['dott', 'lime', 'velib', 'yego'];
const FAILURE_RETRY_MS = 15_000;

export type SharedMobilitySnapshot = {
  items: SharedMobilityItem[];
  sources: Record<SharedMobilityProvider, SharedMobilitySourceStatus>;
};

type CachedProvider = {
  snapshot: { items: SharedMobilityItem[]; source: SharedMobilitySourceStatus };
  reusableUntil: number;
};

const cache = new Map<SharedMobilityProvider, CachedProvider>();
let inFlight: Promise<SharedMobilitySnapshot> | undefined;

/**
 * One process-wide aggregation pass. A provider's own GBFS TTL controls reuse;
 * failed providers only cache the unavailable state briefly and never reuse
 * old vehicle positions.
 */
export function getSharedMobilitySnapshot(): Promise<SharedMobilitySnapshot> {
  if (inFlight) return inFlight;
  inFlight = loadSnapshot().finally(() => {
    inFlight = undefined;
  });
  return inFlight;
}

async function loadSnapshot(): Promise<SharedMobilitySnapshot> {
  const results = await Promise.all(PROVIDERS.map(loadProvider));
  const sources = Object.fromEntries(results.map(({ provider, snapshot }) => [provider, snapshot.source])) as Record<
    SharedMobilityProvider,
    SharedMobilitySourceStatus
  >;
  return {
    items: results.flatMap(({ snapshot }) => snapshot.items),
    sources,
  };
}

async function loadProvider(provider: SharedMobilityProvider) {
  const now = Date.now();
  const cached = cache.get(provider);
  if (cached && cached.reusableUntil > now) {
    return { provider, snapshot: cached.snapshot };
  }

  let parsed;
  try {
    parsed = await fetchSharedMobilityProvider(provider);
  } catch {
    // A malformed or unexpectedly throwing provider adapter is isolated just
    // like a timeout: its unavailable status must not hide the other feeds.
    parsed = null;
  }
  if (!parsed) {
    const snapshot = {
      items: [],
      source: { status: 'unavailable' as const },
    };
    cache.set(provider, { snapshot, reusableUntil: now + FAILURE_RETRY_MS });
    return { provider, snapshot };
  }

  const source: SharedMobilitySourceStatus = {
    status: 'ok',
    ...(parsed.sourceUpdatedAt ? { sourceUpdatedAt: parsed.sourceUpdatedAt } : {}),
    ...(parsed.expiresAt ? { expiresAt: parsed.expiresAt } : {}),
  };
  const snapshot = { items: parsed.items, source };
  const expiresAt = parsed.expiresAt ? new Date(parsed.expiresAt).getTime() : undefined;
  if (parsed.cacheable && expiresAt && expiresAt > now) {
    cache.set(provider, { snapshot, reusableUntil: expiresAt });
  } else {
    cache.delete(provider);
  }
  return { provider, snapshot };
}

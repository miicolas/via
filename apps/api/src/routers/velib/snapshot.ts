import type { BikeStation } from '@via/contract';

import { fetchVelibFeeds } from './client';
import { parseVelibStations } from './parse';

const FRESHNESS_MS = 55_000;
const FAILURE_RETRY_MS = 15_000;

export type VelibSnapshot = {
  stations: BikeStation[];
  sourceAvailable: boolean;
};

let cached: { stations: BikeStation[]; expiresAt: number } | undefined;
let inFlight: Promise<VelibSnapshot> | undefined;
let retryAfter = 0;

/** One process-wide minute snapshot shared by map tiles and search requests. */
export function getVelibSnapshot(): Promise<VelibSnapshot> {
  if (cached && cached.expiresAt > Date.now()) {
    return Promise.resolve({ stations: cached.stations, sourceAvailable: true });
  }
  if (retryAfter > Date.now()) {
    return Promise.resolve({ stations: cached?.stations ?? [], sourceAvailable: false });
  }
  if (inFlight) return inFlight;

  inFlight = loadSnapshot().finally(() => { inFlight = undefined; });
  return inFlight;
}

async function loadSnapshot(): Promise<VelibSnapshot> {
  const feeds = await fetchVelibFeeds();
  const stations = feeds && parseVelibStations(feeds.information, feeds.status);
  if (stations) {
    cached = { stations, expiresAt: Date.now() + FRESHNESS_MS };
    retryAfter = 0;
    return { stations, sourceAvailable: true };
  }

  retryAfter = Date.now() + FAILURE_RETRY_MS;
  return { stations: cached?.stations ?? [], sourceAvailable: false };
}

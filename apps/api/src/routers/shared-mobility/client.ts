import type { SharedMobilityProvider } from '@via/contract';

import { env } from '../../env';
import { fetchJsonOrNull } from '../../http/fetch-json-or-null';
import { fetchVelibFeeds } from '../velib/client';

import {
  combineMeta,
  findManifestFeed,
  IDF_DOTT_SYSTEMS,
  parseDottVehicles,
  parseLimeVehicles,
  parseManifestFeeds,
  parseVelibSharedMobility,
  parseYegoVehicles,
  type ParsedMobilityFeed,
} from './parse';

const SYSTEM_TIMEOUT_MS = env.SHARED_MOBILITY_TIMEOUT_MS;

export type SharedMobilityProviderSnapshot = ParsedMobilityFeed;

const fetchers: Record<
  SharedMobilityProvider,
  () => Promise<ParsedMobilityFeed | null>
> = {
  dott: fetchDott,
  lime: () => fetchSimpleGbfs('lime', env.LIME_GBFS_URL, parseLimeVehicles),
  velib: fetchVelib,
  yego: () => fetchSimpleGbfs('yego', env.YEGO_GBFS_URL, parseYegoVehicles),
};

export async function fetchSharedMobilityProvider(
  provider: SharedMobilityProvider
): Promise<SharedMobilityProviderSnapshot | null> {
  return fetchers[provider]();
}

async function fetchDott(): Promise<ParsedMobilityFeed | null> {
  const manifest = await getJSON(new URL(env.DOTT_GBFS_FRANCE_URL), '[dott] gbfs');
  const feeds = manifest ? parseManifestFeeds(manifest) : null;
  if (!feeds) return null;

  const results = await Promise.all(
    IDF_DOTT_SYSTEMS.map(async (system) => {
      const free = findManifestFeed(feeds, 'free_bike_status', system);
      if (!free) return null;
      const vehicleTypes = findManifestFeed(feeds, 'vehicle_types', system);
      const geofencing = findManifestFeed(feeds, 'geofencing_zones', system);
      const [freeBody, typeBody, geofencingBody] = await Promise.all([
        getJSON(free.url, `[dott:${system}] free_bike_status`),
        vehicleTypes
          ? getJSON(vehicleTypes.url, `[dott:${system}] vehicle_types`)
          : Promise.resolve(null),
        geofencing
          ? getJSON(geofencing.url, `[dott:${system}] geofencing_zones`)
          : Promise.resolve(null),
      ]);
      return parseDottVehicles(freeBody, typeBody, system, new Date(), geofencingBody);
    })
  );

  return combineParsedFeeds(results);
}

/**
 * A single-system GBFS operator: one manifest, one `free_bike_status`, an
 * optional `vehicle_types`. Lime and Yego differ only by the feed they publish
 * and the parser that reads it.
 */
async function fetchSimpleGbfs(
  label: string,
  manifestUrl: string,
  parse: (freeBody: unknown, typeBody: unknown) => ParsedMobilityFeed | null
): Promise<ParsedMobilityFeed | null> {
  const manifest = await getJSON(new URL(manifestUrl), `[${label}] gbfs`);
  const feeds = manifest ? parseManifestFeeds(manifest) : null;
  const free = feeds && findManifestFeed(feeds, 'free_bike_status');
  if (!free) return null;
  const vehicleTypes = findManifestFeed(feeds, 'vehicle_types');
  const [freeBody, typeBody] = await Promise.all([
    getJSON(free.url, `[${label}] free_bike_status`),
    vehicleTypes ? getJSON(vehicleTypes.url, `[${label}] vehicle_types`) : Promise.resolve(null),
  ]);
  return parse(freeBody, typeBody);
}

/**
 * Vélib' goes through `velib/client`, not a second fetcher here: that module
 * holds the process-wide feed window the map tiles and the search already read,
 * so this pass reuses their download rather than racing it.
 */
async function fetchVelib(): Promise<ParsedMobilityFeed | null> {
  const feeds = await fetchVelibFeeds();
  return feeds ? parseVelibSharedMobility(feeds.information, feeds.status) : null;
}

async function getJSON(url: URL, logLabel: string): Promise<unknown | null> {
  return fetchJsonOrNull(url, { timeoutMs: SYSTEM_TIMEOUT_MS, logLabel });
}

function combineParsedFeeds(
  feeds: Array<ParsedMobilityFeed | null>
): ParsedMobilityFeed | null {
  const valid = feeds.filter((feed): feed is ParsedMobilityFeed => feed !== null);
  if (valid.length === 0) return null;
  return {
    items: valid.flatMap((feed) => feed.items),
    ...combineMeta(valid),
  };
}

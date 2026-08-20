import type { AddressSearchResult, Coordinate, SearchResult } from '@via/contract';

import { searchBan } from './ban-client';
import { toAddressResults, toMunicipalityResults } from './ban-mappers';
import { importMeta } from '@via/db/schema';
import { inArray } from 'drizzle-orm';

import { toStationResults } from './mappers';
import { mergeSearchResults } from './merge';
import { selectMatchingStations } from './queries';
import { db } from '@via/db';

/** Per-source fetch sizes, before the merge truncates to `limit`. */
const STATION_LIMIT = 5;
const ADDRESS_LIMIT = 5;

export type PlaceSearch = {
  results: SearchResult[];
  /** Commune centres kept separately so the resolver does not confuse them with nearby streets. */
  municipalities: AddressSearchResult[];
  /** False when the BAN geocoder was unreachable, so addresses are missing. */
  banAvailable: boolean;
  accessibility: AccessibilitySourceStatus;
};

export type AccessibilitySourceStatus = {
  status: 'ok' | 'unavailable';
  sourceUpdatedAt?: string;
  importedAt?: string;
};

const ACCESSIBILITY_META_KEYS = [
  'accessibility:source-updated-at',
  'accessibility:imported-at',
] as const;

export async function readAccessibilitySourceStatus(): Promise<AccessibilitySourceStatus> {
  const rows = await db
    .select({ key: importMeta.key, value: importMeta.value })
    .from(importMeta)
    .where(inArray(importMeta.key, [...ACCESSIBILITY_META_KEYS]));
  const values = new Map(rows.map((row) => [row.key, row.value]));
  const importedAt = values.get('accessibility:imported-at');
  return {
    status: importedAt ? 'ok' : 'unavailable',
    sourceUpdatedAt: values.get('accessibility:source-updated-at'),
    importedAt,
  };
}

/**
 * The one station+address search pipeline. Every feature that resolves a
 * free-text place (search sheet, natural-language journeys) must go through
 * it so they all see the same candidates.
 */
export async function searchPlaces(
  q: string,
  {
    limit,
    origin,
    signal,
  }: {
    limit: number;
    origin?: Coordinate;
    signal?: AbortSignal;
  }
): Promise<PlaceSearch> {
  const [stationRows, banFeatures, accessibility] = await Promise.all([
    selectMatchingStations(q, STATION_LIMIT, origin),
    searchBan(q, { limit: ADDRESS_LIMIT, origin, signal }),
    readAccessibilitySourceStatus(),
  ]);
  const addresses = toAddressResults(banFeatures ?? []);
  return {
    results: mergeSearchResults(toStationResults(stationRows), addresses, {
      q,
      limit,
      origin,
    }),
    municipalities: toMunicipalityResults(banFeatures ?? []),
    banAvailable: banFeatures !== null,
    accessibility,
  };
}

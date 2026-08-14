import type { AddressSearchResult, Coordinate, SearchResult } from '@via/contract';

import { searchBan } from './ban-client';
import { toAddressResults, toMunicipalityResults } from './ban-mappers';
import { toStationResults } from './mappers';
import { mergeSearchResults } from './merge';
import { selectMatchingStations } from './queries';

/** Per-source fetch sizes, before the merge truncates to `limit`. */
const STATION_LIMIT = 5;
const ADDRESS_LIMIT = 5;

export type PlaceSearch = {
  results: SearchResult[];
  /** Commune centres kept separately so the resolver does not confuse them with nearby streets. */
  municipalities: AddressSearchResult[];
  /** False when the BAN geocoder was unreachable, so addresses are missing. */
  banAvailable: boolean;
};

/**
 * The one station+address search pipeline. Every feature that resolves a
 * free-text place (search sheet, natural-language journeys) must go through
 * it so they all see the same candidates.
 */
export async function searchPlaces(
  q: string,
  { limit, origin, signal }: { limit: number; origin?: Coordinate; signal?: AbortSignal }
): Promise<PlaceSearch> {
  const [stationRows, banFeatures] = await Promise.all([
    selectMatchingStations(q, STATION_LIMIT, origin),
    searchBan(q, { limit: ADDRESS_LIMIT, origin, signal }),
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
  };
}

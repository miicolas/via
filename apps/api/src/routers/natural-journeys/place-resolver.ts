import type { Coordinate, SearchResult } from '@via/contract';

import { searchPlaces } from '../search/search-places';

export type PlaceResolution =
  | { status: 'resolved'; result: SearchResult }
  | { status: 'ambiguous'; candidates: SearchResult[] }
  | { status: 'not_found'; candidates: [] }
  | { status: 'unavailable'; candidates: SearchResult[] };

export type PlaceResolver = {
  resolve: (query: string, origin?: Coordinate, signal?: AbortSignal) => Promise<PlaceResolution>;
};

export const placeResolver: PlaceResolver = {
  resolve: async (query, origin, signal) => {
    const search = await searchPlaces(query, {
      limit: 10,
      origin,
      signal,
    });
    const { results: candidates, banAvailable } = search;
    const municipalities = search.municipalities ?? [];
    const stationCandidates = candidates.filter((candidate) => candidate.kind === 'station');
    const addressCandidates = candidates.filter((candidate) => candidate.kind === 'address');
    const addressQuery = looksLikeAddress(query);

    if (!addressQuery) {
      const exactMunicipalities = municipalities.filter(
        (candidate) => normalizePlaceName(candidate.name) === normalizePlaceName(query)
      );
      if (exactMunicipalities.length === 1) {
        return { status: 'resolved', result: exactMunicipalities[0]! };
      }

      const exactStations = stationCandidates.filter(
        (candidate) => normalizePlaceName(candidate.name) === normalizePlaceName(query)
      );
      if (exactStations.length === 1) return { status: 'resolved', result: exactStations[0]! };

      // BAN already applies fuzzy spelling ranking. A single commune match is
      // therefore a complete destination, not a request for a street inside it.
      if (municipalities.length === 1) return { status: 'resolved', result: municipalities[0]! };
      if (municipalities.length > 1) {
        return { status: 'ambiguous', candidates: municipalities };
      }
    }

    const relevantCandidates = addressQuery ? addressCandidates : stationCandidates;
    const rankedCandidates = relevantCandidates.length > 0 ? relevantCandidates : candidates;
    const exact = rankedCandidates.filter(
      (candidate) => normalizePlaceName(candidate.name) === normalizePlaceName(query)
    );
    if (exact.length === 1) return { status: 'resolved', result: exact[0]! };
    if (!looksLikeAddress(query) && stationCandidates.length > 0) {
      return { status: 'resolved', result: stationCandidates[0]! };
    }
    if (rankedCandidates.length === 1) {
      return { status: 'resolved', result: rankedCandidates[0]! };
    }
    if (rankedCandidates.length > 0) {
      return { status: 'ambiguous', candidates: rankedCandidates };
    }
    return banAvailable
      ? { status: 'not_found', candidates: [] }
      : { status: 'unavailable', candidates: [] };
  },
};

/** The canonical "same place name" comparison: accent- and case-insensitive. */
export function normalizePlaceName(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[-‐‑‒–—]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .toLocaleLowerCase('fr-FR');
}

const ADDRESS_PATTERN =
  /(?:^|\s)(?:\d{1,4}|rue|route|avenue|av|boulevard|bd|allée|allee|chemin|impasse|quai|passage|place|square|cours|voie|sentier|résidence|residence)(?:\s|$)/i;

function looksLikeAddress(query: string) {
  return ADDRESS_PATTERN.test(query.trim());
}

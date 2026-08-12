import type {
  AddressSearchResult,
  Coordinate,
  SearchResult,
  StationSearchResult,
} from '@via/contract';

import { haversineMeters } from '../../geo/distance';

type MergeOptions = {
  q: string;
  limit: number;
  origin?: Coordinate;
};

/**
 * One ranked list out of two sources. The interleaving reads the user's intent
 * from the query shape: "12 rue de Rivoli" starts with a digit, nobody types
 * that looking for a station — addresses first. Anything else leads with
 * stations, this being a transit app. Within each source the upstream order
 * stands: SQL ranking for stations, BAN's scoring for addresses.
 */
export function mergeSearchResults(
  stations: StationSearchResult[],
  addresses: AddressSearchResult[],
  { q, limit, origin }: MergeOptions
): SearchResult[] {
  const ordered: SearchResult[] = /^\d/.test(q.trim())
    ? [...addresses, ...stations]
    : [...stations, ...addresses];

  return ordered.slice(0, limit).map((result) =>
    origin
      ? { ...result, distanceMeters: Math.round(haversineMeters(origin, result.coordinate)) }
      : result
  );
}

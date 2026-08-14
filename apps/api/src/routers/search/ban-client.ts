import type { Coordinate } from '@via/contract';

import { env } from '../../env';
import { fetchJsonOrNull } from '../../http/fetch-json-or-null';

/**
 * The geocoder rejects queries shorter than this (and ones not starting with a
 * letter or digit), so we skip the round-trip instead of collecting a 400.
 */
const BAN_MIN_QUERY_LENGTH = 3;

/**
 * Long enough to absorb the geocoder's slow tail when it throttles our shared
 * IP; past this the response degrades to stations-only rather than hanging.
 */
const BAN_TIMEOUT_MS = 4_000;

/** The eight departments that make up Île-de-France. */
const ILE_DE_FRANCE_DEPARTMENT_CODES = ['75', '77', '78', '91', '92', '93', '94', '95'];

/** The subset of a BAN GeoJSON feature the mapper reads. */
export type BanFeature = {
  geometry?: { type?: string; coordinates?: unknown };
  properties?: {
    id?: unknown;
    type?: unknown;
    name?: unknown;
    postcode?: unknown;
    city?: unknown;
  };
};

type BanSearchOptions = {
  limit: number;
  /** Sent as lat/lon so the BAN ranks nearby addresses first. */
  origin?: Coordinate;
  signal?: AbortSignal;
};

/**
 * Queries the Géoplateforme geocoder (Base Adresse Nationale) in autocomplete
 * mode. Free, keyless, ~50 req/s per IP — and this server is one IP for every
 * user, which the client-side debounce is what keeps affordable.
 *
 * Returns `[]` for queries the BAN would reject (too short), and `null` when
 * the geocoder itself failed — the distinction is the response's `sources.ban`:
 * a short query is not an outage. Never throws: an address outage must degrade
 * to a stations-only response, not a 500.
 */
export async function searchBan(
  query: string,
  { limit, origin, signal }: BanSearchOptions
): Promise<BanFeature[] | null> {
  if (!isGeocodable(query)) return [];

  const url = buildBanSearchUrl(query, { limit, origin });

  const collection = (await fetchJsonOrNull(url, {
    signal,
    timeoutMs: BAN_TIMEOUT_MS,
    logLabel: '[search] BAN',
  })) as { features?: BanFeature[] } | null;

  return collection === null ? null : (collection.features ?? []);
}

export function buildBanSearchUrl(
  query: string,
  { limit, origin }: Pick<BanSearchOptions, 'limit' | 'origin'>
): URL {
  const url = new URL(env.BAN_SEARCH_URL);
  url.searchParams.set('q', query);
  url.searchParams.set('autocomplete', '1');
  url.searchParams.set('limit', String(limit));
  url.searchParams.set('depcode', ILE_DE_FRANCE_DEPARTMENT_CODES.join(','));
  if (origin) {
    url.searchParams.set('lat', String(origin.latitude));
    url.searchParams.set('lon', String(origin.longitude));
  }
  return url;
}

function isGeocodable(query: string): boolean {
  return query.length >= BAN_MIN_QUERY_LENGTH && /^[\p{L}\p{N}]/u.test(query);
}

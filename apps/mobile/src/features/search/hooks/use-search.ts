import type { SearchInput, SearchResponse, SearchResult } from '@via/contract';
import { useEffect, useState } from 'react';

import type { UserLocationState } from '@/features/map/model/types';
import { api } from '@/lib/api';

/** The client leaves `limit` to the server's default. */
type SearchQuery = Omit<SearchInput, 'limit'>;

/** The one remote operation the search request cycle needs. */
export type SearchPort = {
  search: (input: SearchQuery, signal: AbortSignal) => Promise<SearchResponse>;
};

export type SearchState = {
  status: 'idle' | 'loading' | 'ready' | 'error';
  results: SearchResult[];
  banUnavailable: boolean;
};

type SettledSearch = {
  forQuery: string;
  response?: SearchResponse;
};

/**
 * Every keystroke pause longer than this costs one BAN request, and the server
 * is one IP for all users against the geocoder's rate limit — 300 ms let a
 * hesitant typist burst enough requests to get the server throttled.
 */
export const SEARCH_DEBOUNCE_MS = 600;

/**
 * Four decimals ≈ 11 m: precise enough to rank results, stable enough that GPS
 * jitter does not mint a new URL — and a new HTTP cache entry — per keystroke.
 */
const POSITION_PRECISION = 1e4;

/**
 * Server-backed search, including debounce, cancellation, staleness protection
 * and the state shown by callers. The narrow port is the only remote seam.
 */
export function useSearch(
  query: string,
  location: UserLocationState,
  port: SearchPort = apiSearchPort
): SearchState {
  const [settled, setSettled] = useState<SettledSearch>();

  const latitude =
    location.status === 'ready' ? roundCoordinate(location.coordinate.latitude) : undefined;
  const longitude =
    location.status === 'ready' ? roundCoordinate(location.coordinate.longitude) : undefined;

  useEffect(() => {
    const currentQuery = query.trim();
    if (!currentQuery) return;

    const controller = new AbortController();
    const timer = setTimeout(() => {
      const position =
        latitude !== undefined && longitude !== undefined ? { latitude, longitude } : undefined;

      port
        .search({ q: currentQuery, ...position }, controller.signal)
        .then((response) => setSettled({ forQuery: currentQuery, response }))
        .catch((cause: unknown) => {
          if (controller.signal.aborted) return;
          console.error('[search] La recherche a échoué', cause);
          setSettled({ forQuery: currentQuery });
        });
    }, SEARCH_DEBOUNCE_MS);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [query, latitude, longitude, port]);

  return deriveSearchState(query, settled);
}

function roundCoordinate(value: number): number {
  return Math.round(value * POSITION_PRECISION) / POSITION_PRECISION;
}

const apiSearchPort: SearchPort = {
  search: (input, signal) => api.search.query(input, { signal }),
};

function deriveSearchState(query: string, settled?: SettledSearch): SearchState {
  const currentQuery = query.trim();
  if (!currentQuery) return { status: 'idle', results: [], banUnavailable: false };

  if (!settled || settled.forQuery !== currentQuery) {
    return {
      status: 'loading',
      results: settled?.response?.results ?? [],
      banUnavailable: false,
    };
  }

  if (!settled.response) return { status: 'error', results: [], banUnavailable: false };

  return {
    status: 'ready',
    results: settled.response.results,
    banUnavailable: settled.response.sources.ban === 'unavailable',
  };
}

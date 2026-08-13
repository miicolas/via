import type { ContractRouterClient } from '@orpc/contract';
import type { contract } from '@via/contract';
import { useEffect, useState } from 'react';

import { searchState, type SearchState, type SettledSearch } from '@/features/search/model/state';
import type { UserLocationState } from '@/features/map/model/types';
import { api } from '@/lib/api';

type ApiClient = ContractRouterClient<typeof contract>;

const DEBOUNCE_MS = 300;

/**
 * Four decimals ≈ 11 m: precise enough to rank results, stable enough that GPS
 * jitter does not mint a new URL — and a new HTTP cache entry — per keystroke.
 */
const POSITION_PRECISION = 1e4;

/**
 * Server-backed search, debounced. The client is a parameter for the same
 * reason as `useMetroNetwork`: it is the seam that lets this be exercised with
 * a fake. All the deriving lives in `searchState`; this file holds effects and
 * nothing else.
 */
export function useSearch(
  query: string,
  location: UserLocationState,
  client: ApiClient = api
): SearchState {
  const [settled, setSettled] = useState<SettledSearch>();

  const latitude = location.status === 'ready' ? roundCoordinate(location.coordinate.latitude) : undefined;
  const longitude = location.status === 'ready' ? roundCoordinate(location.coordinate.longitude) : undefined;

  useEffect(() => {
    const currentQuery = query.trim();
    if (!currentQuery) return;

    const controller = new AbortController();
    const timer = setTimeout(() => {
      const position =
        latitude !== undefined && longitude !== undefined ? { latitude, longitude } : undefined;

      client.search
        .query({ q: currentQuery, ...position }, { signal: controller.signal })
        .then((response) => setSettled({ forQuery: currentQuery, response }))
        .catch((cause: unknown) => {
          if (controller.signal.aborted) return;
          console.error('[search] La recherche a échoué', cause);
          setSettled({ forQuery: currentQuery });
        });
    }, DEBOUNCE_MS);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [query, latitude, longitude, client]);

  return searchState(query, settled);
}

function roundCoordinate(value: number): number {
  return Math.round(value * POSITION_PRECISION) / POSITION_PRECISION;
}

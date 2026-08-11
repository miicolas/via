import type { ContractRouterClient } from '@orpc/contract';
import type { contract } from '@via/contract';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { api, apiBaseUrl } from '@/lib/api';
import { LOAD_FAILED_MESSAGE, networkState, type NetworkState } from '@/lib/metro-network';

type ApiClient = ContractRouterClient<typeof contract>;

export type MetroNetwork = {
  state: NetworkState;
  select: (routeId: string) => void;
  retry: () => void;
};

/**
 * Loads the whole metro network once and owns which line is shown.
 *
 * The client is a parameter rather than a module-level capture: that is the only
 * seam in the app, and it is what lets the load-and-retry path be exercised with
 * a fake instead of a running server.
 *
 * All the deriving lives in `networkState`, so this file holds effects and
 * nothing else.
 */
export function useMetroNetwork(client: ApiClient = api): MetroNetwork {
  const [network, setNetwork] = useState<Awaited<ReturnType<ApiClient['network']['map']>>>();
  const [error, setError] = useState<string>();
  const [attempt, setAttempt] = useState(0);
  const [selectedRouteId, setSelectedRouteId] = useState<string>();

  useEffect(() => {
    const controller = new AbortController();

    client.network
      .map(undefined, { signal: controller.signal })
      .then(setNetwork)
      .catch((cause: unknown) => {
        if (controller.signal.aborted) return;
        console.error(`[map] Failed to load metro network from ${apiBaseUrl}`, cause);
        setError(LOAD_FAILED_MESSAGE);
      });

    return () => controller.abort();
  }, [attempt, client]);

  const state = useMemo(
    () => networkState(network, error, selectedRouteId),
    [network, error, selectedRouteId]
  );

  const select = useCallback((routeId: string) => setSelectedRouteId(routeId), []);
  const retry = useCallback(() => {
    setError(undefined);
    setAttempt((value) => value + 1);
  }, []);

  return { state, select, retry };
}

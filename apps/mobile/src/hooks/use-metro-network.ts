import type { NetworkMap, NetworkRoute, NetworkStation } from '@via/contract';
import { useCallback, useEffect, useMemo, useState } from 'react';

import { api, apiBaseUrl } from '@/lib/api';
import { resolveLine, sortRoutes, type LineView } from '@/lib/metro-network';

/** The one remote operation the network request cycle needs. */
export type NetworkPort = {
  load: (signal: AbortSignal) => Promise<NetworkMap>;
};

export type NetworkState =
  | { status: 'loading' }
  | { status: 'error'; message: string }
  | { status: 'ready'; lines: NetworkRoute[]; stations: NetworkStation[]; line: LineView };

export const LOAD_FAILED_MESSAGE =
  'Le réseau de transport ne peut pas être chargé pour le moment.';
export const EMPTY_NETWORK_MESSAGE = 'Aucune ligne de transport à afficher.';

export type MetroNetwork = {
  network?: NetworkMap;
  state: NetworkState;
  select: (routeId: string) => void;
  retry: () => void;
};

/**
 * Loads the whole visible transit network once and owns which line is shown.
 *
 * Loading, retry, selection and visible state stay behind this interface. The
 * narrow port lets tests replace only the one remote operation involved.
 */
export function useMetroNetwork(port: NetworkPort = apiNetworkPort): MetroNetwork {
  const [network, setNetwork] = useState<NetworkMap>();
  const [error, setError] = useState<string>();
  const [attempt, setAttempt] = useState(0);
  const [selectedRouteId, setSelectedRouteId] = useState<string>();

  useEffect(() => {
    const controller = new AbortController();

    port
      .load(controller.signal)
      .then(setNetwork)
      .catch((cause: unknown) => {
        if (controller.signal.aborted) return;
        console.error(`[map] Failed to load transit network from ${apiBaseUrl}`, cause);
        setError(LOAD_FAILED_MESSAGE);
      });

    return () => controller.abort();
  }, [attempt, port]);

  const state = useMemo(
    () => deriveNetworkState(network, error, selectedRouteId),
    [network, error, selectedRouteId]
  );

  const select = useCallback((routeId: string) => setSelectedRouteId(routeId), []);
  const retry = useCallback(() => {
    setError(undefined);
    setAttempt((value) => value + 1);
  }, []);

  return { network, state, select, retry };
}

const apiNetworkPort: NetworkPort = {
  load: (signal) => api.network.map(undefined, { signal }),
};

function deriveNetworkState(
  network: NetworkMap | undefined,
  error: string | undefined,
  selectedRouteId: string | undefined
): NetworkState {
  if (!network) {
    return error ? { status: 'error', message: error } : { status: 'loading' };
  }

  const lines = sortRoutes(network.routes);
  const line = resolveLine(lines, network.stations, selectedRouteId);

  if (!line) return { status: 'error', message: EMPTY_NETWORK_MESSAGE };

  return { status: 'ready', lines, stations: network.stations, line };
}

import { useCallback, useEffect, useMemo, useState } from 'react';

import { apiBaseUrl } from '@/lib/api';
import { fetchNetworkMap, sortRoutes, type NetworkMap } from '@/lib/network-map';

/** Loads the whole metro network once, with a manual retry. */
export function useNetworkMap() {
  const [data, setData] = useState<NetworkMap>();
  const [error, setError] = useState<string>();
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();

    fetchNetworkMap(controller.signal)
      .then(setData)
      .catch((cause: unknown) => {
        if (controller.signal.aborted) return;
        console.error(`[map] Failed to load metro network from ${apiBaseUrl}`, cause);
        setError('Le réseau de métro ne peut pas être chargé pour le moment.');
      });

    return () => controller.abort();
  }, [attempt]);

  const routes = useMemo(() => sortRoutes(data?.routes ?? []), [data]);
  const stations = useMemo(() => data?.stations ?? [], [data]);
  const reload = useCallback(() => {
    setError(undefined);
    setAttempt((value) => value + 1);
  }, []);

  const status = data ? 'ready' : error ? 'error' : 'loading';

  return { status, routes, stations, error, reload };
}

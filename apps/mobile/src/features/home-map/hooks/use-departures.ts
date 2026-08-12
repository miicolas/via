import type { ContractRouterClient } from '@orpc/contract';
import type { contract } from '@via/contract';
import { useEffect, useState } from 'react';
import { AppState } from 'react-native';

import {
  departuresState,
  type DeparturesState,
  type SettledDepartures,
} from '@/features/home-map/model/departures-state';
import { api } from '@/lib/api';

type ApiClient = ContractRouterClient<typeof contract>;

/**
 * Half the server cache TTL: polling faster would only re-download the same
 * cached payload, and the row countdowns already move on `useNow` between
 * refreshes.
 */
const POLL_MS = 60_000;

/**
 * Departures for the active station, kept fresh while the screen is on it.
 * Polls every minute, pauses in the background and refetches on return — a
 * backgrounded app must not keep spending server (and PRIM budget) cycles.
 * Mounted by `HomeStationSection` only, so closing the sheet or switching to
 * search unmounts it and stops the polling by construction. The client is a
 * parameter for the same reason as `useSearch`: it is the test seam.
 */
export function useDepartures(stationId: string, client: ApiClient = api): DeparturesState {
  const [settled, setSettled] = useState<SettledDepartures>();

  useEffect(() => {
    const controller = new AbortController();

    const load = () => {
      client.departures
        .forStation({ stationId }, { signal: controller.signal })
        .then((response) => setSettled({ forStationId: stationId, response }))
        .catch((cause: unknown) => {
          if (controller.signal.aborted) return;
          console.error('[departures] Le chargement des passages a échoué', cause);
          // A failed refresh keeps the previous answer: stale minutes beat a
          // blank screen. Only a station with no answer yet surfaces the error.
          setSettled((previous) =>
            previous?.forStationId === stationId && previous.response
              ? previous
              : { forStationId: stationId }
          );
        });
    };

    load();
    let timer: ReturnType<typeof setInterval> | undefined = setInterval(load, POLL_MS);

    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        if (!timer) {
          load();
          timer = setInterval(load, POLL_MS);
        }
      } else if (timer) {
        clearInterval(timer);
        timer = undefined;
      }
    });

    return () => {
      controller.abort();
      if (timer) clearInterval(timer);
      subscription.remove();
    };
  }, [stationId, client]);

  return departuresState(stationId, settled);
}

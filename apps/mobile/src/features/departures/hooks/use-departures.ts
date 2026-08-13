import type { DeparturesResponse } from '@via/contract';
import { useEffect, useState } from 'react';
import { AppState, type AppStateStatus } from 'react-native';

import { api } from '@/lib/api';

/** The one remote operation the departures request cycle needs. */
export type DeparturesPort = {
  load: (stationId: string, signal: AbortSignal) => Promise<DeparturesResponse>;
};

/** Internal platform seams, replaceable by controlled adapters in hook tests. */
export type DeparturesEnvironment = {
  scheduleEvery: (callback: () => void, intervalMs: number) => () => void;
  subscribeAppState: (listener: (state: AppStateStatus) => void) => () => void;
};

export type DeparturesState =
  | { status: 'loading' }
  | { status: 'error' }
  | { status: 'ready'; response: DeparturesResponse };

type SettledDepartures = {
  forStationId: string;
  response?: DeparturesResponse;
};

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
 * Mounted by `StationSection` only, so closing the sheet or switching to
 * search unmounts it and stops the polling by construction.
 */
export function useDepartures(
  stationId: string,
  port: DeparturesPort = apiDeparturesPort,
  environment: DeparturesEnvironment = nativeDeparturesEnvironment
): DeparturesState {
  const [settled, setSettled] = useState<SettledDepartures>();

  useEffect(() => {
    const controller = new AbortController();

    const load = () => {
      port
        .load(stationId, controller.signal)
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
    let stopPolling: (() => void) | undefined = environment.scheduleEvery(load, POLL_MS);

    const unsubscribe = environment.subscribeAppState((state) => {
      if (state === 'active') {
        if (!stopPolling) {
          load();
          stopPolling = environment.scheduleEvery(load, POLL_MS);
        }
      } else if (stopPolling) {
        stopPolling();
        stopPolling = undefined;
      }
    });

    return () => {
      controller.abort();
      stopPolling?.();
      unsubscribe();
    };
  }, [stationId, port, environment]);

  return deriveDeparturesState(stationId, settled);
}

const apiDeparturesPort: DeparturesPort = {
  load: (stationId, signal) => api.departures.forStation({ stationId }, { signal }),
};

const nativeDeparturesEnvironment: DeparturesEnvironment = {
  scheduleEvery: (callback, intervalMs) => {
    const timer = setInterval(callback, intervalMs);
    return () => clearInterval(timer);
  },
  subscribeAppState: (listener) => {
    const subscription = AppState.addEventListener('change', listener);
    return () => subscription.remove();
  },
};

function deriveDeparturesState(
  stationId: string,
  settled?: SettledDepartures
): DeparturesState {
  if (!settled || settled.forStationId !== stationId) return { status: 'loading' };
  if (!settled.response) return { status: 'error' };
  return { status: 'ready', response: settled.response };
}

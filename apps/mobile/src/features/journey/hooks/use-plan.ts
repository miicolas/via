import type { JourneyInput, JourneysResponse } from '@via/contract';
import { useEffect, useRef, useState } from 'react';

import type { JourneyRequest } from '@/features/journey/model/request';
import { api } from '@/lib/api';

/** The one remote operation the journey request cycle needs. */
export type JourneyPort = {
  plan: (input: JourneyInput, signal: AbortSignal) => Promise<JourneysResponse>;
};

export type JourneyState =
  | { status: 'idle' }
  | { status: 'planning'; request: JourneyRequest }
  | { status: 'ready'; request: JourneyRequest; response: JourneysResponse }
  | { status: 'error'; request: JourneyRequest };

type SettledJourney = {
  key: string;
  response?: JourneysResponse;
};

/** One explicit, cancellable calculation. It never refetches on focus or detail changes. */
export function useJourneyPlan(
  request: JourneyRequest | undefined,
  port: JourneyPort = apiJourneyPort
): JourneyState {
  const [settled, setSettled] = useState<SettledJourney>();
  const requestRef = useRef(request);
  requestRef.current = request;
  const requestKey = request?.key;

  useEffect(() => {
    const activeRequest = requestRef.current;
    if (!activeRequest) return;
    const controller = new AbortController();
    port
      .plan(
        {
          origin: activeRequest.origin,
          destination: activeRequest.destination,
          limit: 4,
        },
        controller.signal
      )
      .then((response) => setSettled({ key: activeRequest.key, response }))
      .catch((cause: unknown) => {
        if (controller.signal.aborted) return;
        console.error('[journeys] Le calcul a échoué', cause);
        setSettled({ key: activeRequest.key });
      });

    return () => controller.abort();
  }, [port, requestKey]);

  return deriveJourneyState(request, settled);
}

const apiJourneyPort: JourneyPort = {
  plan: (input, signal) => api.journeys.plan(input, { signal }),
};

function deriveJourneyState(
  request: JourneyRequest | undefined,
  settled?: SettledJourney
): JourneyState {
  if (!request) return { status: 'idle' };
  if (!settled || settled.key !== request.key) return { status: 'planning', request };
  if (!settled.response) return { status: 'error', request };
  return { status: 'ready', request, response: settled.response };
}

import type { ContractRouterClient } from '@orpc/contract';
import type { contract } from '@via/contract';
import { useEffect, useState } from 'react';

import {
  journeyState,
  type JourneyRequest,
  type JourneyState,
  type SettledJourney,
} from '@/features/home-map/model/journey-state';
import { api } from '@/lib/api';

type ApiClient = ContractRouterClient<typeof contract>;

/** One explicit, cancellable calculation. It never refetches on focus or detail changes. */
export function useJourneyPlan(
  request: JourneyRequest | undefined,
  client: ApiClient = api
): JourneyState {
  const [settled, setSettled] = useState<SettledJourney>();

  useEffect(() => {
    if (!request) return;
    const controller = new AbortController();
    client.journeys
      .plan(
        {
          origin: request.origin,
          destination: request.destination,
          limit: 4,
        },
        { signal: controller.signal }
      )
      .then((response) => setSettled({ key: request.key, response }))
      .catch((cause: unknown) => {
        if (controller.signal.aborted) return;
        console.error('[journeys] Le calcul a échoué', cause);
        setSettled({ key: request.key });
      });

    return () => controller.abort();
  }, [client, request]);

  return journeyState(request, settled);
}

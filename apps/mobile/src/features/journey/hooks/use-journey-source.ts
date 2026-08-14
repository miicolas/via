import type { JourneyDestination, JourneysResponse } from '@via/contract';
import { useCallback, useMemo, useState } from 'react';

import type { NaturalJourneyState } from '@/features/journey/hooks/use-natural-journey';
import { useJourneyPlan, type JourneyState } from '@/features/journey/hooks/use-plan';
import { injectedJourneyPlan } from '@/features/journey/model/injected-journey-plan';
import { naturalJourneyPlan } from '@/features/journey/model/natural-journey-plan';
import { journeyRequestKey, type JourneyRequest } from '@/features/journey/model/request';
import type { UserLocationState } from '@/features/map/model/types';

type InjectedJourney = { destination: JourneyDestination; response: JourneysResponse };

type JourneySourceOptions = {
  destination: JourneyDestination | undefined;
  retryGeneration: number;
  location: UserLocationState;
  naturalJourney: NaturalJourneyState;
};

/**
 * The one place that decides which journey the UI shows: an itinerary injected
 * by the Via chat, a ready natural-language answer, or the classic planner —
 * whichever owns the current destination.
 */
export function useJourneySource({
  destination,
  retryGeneration,
  location,
  naturalJourney,
}: JourneySourceOptions) {
  const [injected, setInjected] = useState<InjectedJourney | undefined>();
  const coordinate = location.status === 'ready' ? location.coordinate : undefined;
  const injectedActive = injected !== undefined && destination?.id === injected.destination.id;

  const request = useMemo<JourneyRequest | undefined>(() => {
    if (injectedActive || naturalJourney.status !== 'idle' || !destination || !coordinate) {
      return undefined;
    }
    return {
      key: journeyRequestKey(coordinate, destination, retryGeneration),
      origin: coordinate,
      destination,
    };
  }, [coordinate, destination, injectedActive, naturalJourney.status, retryGeneration]);
  const classic = useJourneyPlan(request);

  const journey = useMemo<JourneyState>(() => {
    if (injectedActive) {
      return injectedJourneyPlan(injected.destination, injected.response, coordinate);
    }
    if (naturalJourney.status === 'ready') {
      return naturalJourneyPlan(naturalJourney.response, coordinate);
    }
    return classic;
  }, [classic, coordinate, injected, injectedActive, naturalJourney]);

  const inject = useCallback(
    (into: JourneyDestination, response: JourneysResponse) =>
      setInjected({ destination: into, response }),
    []
  );
  const clearInjected = useCallback(() => setInjected(undefined), []);

  return { journey, inject, clearInjected };
}

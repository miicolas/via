import type { Coordinate, JourneyDestination, JourneysResponse } from '@via/contract';

import type { JourneyState } from '@/features/journey/hooks/use-plan';
import { journeyRequestKey } from '@/features/journey/model/request';

/**
 * Presents an already-computed response (e.g. what the Via chat's planner tool
 * returned) as the `JourneyState` the journey UI consumes, so the user sees
 * exactly the itinerary the assistant described — not a fresh computation.
 */
export function injectedJourneyPlan(
  destination: JourneyDestination,
  response: JourneysResponse,
  location: Coordinate | undefined
): JourneyState {
  const origin = location ?? destination.coordinate;
  return {
    status: 'ready',
    request: {
      key: `${journeyRequestKey(origin, destination)}:${response.generatedAt}`,
      origin,
      destination,
    },
    response,
  };
}

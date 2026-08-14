import type { Coordinate, NaturalJourneyResponse } from '@via/contract';

import type { JourneyState } from '@/features/journey/hooks/use-plan';
import { journeyRequestKey } from '@/features/journey/model/request';

type ReadyResponse = Extract<NaturalJourneyResponse, { status: 'ready' }>;

/**
 * Presents a ready natural-journey response as the same `JourneyState` the
 * classic planner yields, so downstream journey UI needs no second code path.
 */
export function naturalJourneyPlan(
  response: ReadyResponse,
  location: Coordinate | undefined
): JourneyState {
  const { destination, requestedAt } = response.interpretation;
  const origin = location ?? destination.coordinate;
  return {
    status: 'ready',
    request: {
      key: `${journeyRequestKey(origin, destination)}:${requestedAt}`,
      origin,
      destination,
    },
    response: response.journeys,
  };
}

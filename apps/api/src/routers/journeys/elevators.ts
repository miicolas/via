import type { Journey, JourneyInput, JourneysResponse } from '@via/contract';

import {
  elevatorStatusesForStationIDs,
  readElevatorSourceStatus,
} from '../elevators';
import { canonicalStationIDs, usedStationIDs } from './accessibility';

/** Applies the conservative lift filter after PMR qualification from either planner. */
export async function applyOperationalElevatorConstraint(
  response: JourneysResponse,
  input: JourneyInput
): Promise<JourneysResponse> {
  if (!input.requiresOperationalElevators) return response;

  const source = await readElevatorSourceStatus();
  if (source.status !== 'ok') {
    return {
      ...response,
      status: 'unavailable',
      reason: 'elevator-data-unavailable',
      journeys: [],
    };
  }
  if (response.journeys.length === 0) return response;

  const rawIDs = response.journeys.flatMap(usedStationIDs);
  const canonical = await canonicalStationIDs(rawIDs);
  const statuses = await elevatorStatusesForStationIDs(canonical.values());
  const journeys = response.journeys.filter((journey) =>
    journeyHasOperationalElevators(journey, canonical, statuses)
  );

  return {
    ...response,
    status: journeys.length > 0 ? 'ready' : 'no-route',
    reason: journeys.length > 0 ? response.reason : 'no-operational-elevator-route',
    journeys,
  };
}

export function journeyHasOperationalElevators(
  journey: Journey,
  canonical: ReadonlyMap<string, string>,
  statuses: ReadonlyMap<string, readonly ('available' | 'notavailable' | 'unknown')[]>
) {
  const used = usedStationIDs(journey);
  if (used.length === 0) return true;

  return used.every((rawID) => {
    const stationID = canonical.get(rawID);
    const stationStatuses = stationID ? statuses.get(stationID) : undefined;
    return stationStatuses !== undefined &&
      stationStatuses.length > 0 &&
      stationStatuses.every((status) => status === 'available');
  });
}

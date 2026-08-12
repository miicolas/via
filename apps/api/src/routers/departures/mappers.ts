import type { DepartureGroup } from '@via/contract';

import { groupDepartures } from './group-departures';
import type { NormalizedVisit } from './prim/parse';

/**
 * PRIM visits → contract groups. What is specific here: trains that have
 * already left are dropped — the grouping itself, filtering included, is the
 * shared machinery.
 */
export function toDepartureGroups(
  visits: NormalizedVisit[],
  stationRouteIds: string[],
  now: Date
): DepartureGroup[] {
  return groupDepartures(
    visits
      .filter((visit) => Date.parse(visit.expectedAt) >= now.getTime())
      .map((visit) => ({
        routeId: visit.routeId,
        destination: visit.destination,
        at: visit.expectedAt,
      })),
    stationRouteIds
  );
}

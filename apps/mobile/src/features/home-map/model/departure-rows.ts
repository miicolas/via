import type { DepartureGroup, NetworkRoute } from '@via/contract';

import { waitTimes, type WaitTimes } from '@/features/home-map/model/wait-times';

/** One row of the station's departure board, ready to render. */
export type DepartureRowDescriptor = {
  key: string;
  route: NetworkRoute;
  destination: string;
  wait: WaitTimes;
};

/**
 * Pairs each of the station's lines with departure groups that still have an
 * announced passage to display. Missing, empty, and expired groups do not
 * create placeholder rows.
 */
export function departureRows(
  routes: NetworkRoute[],
  groups: DepartureGroup[],
  now: Date
): DepartureRowDescriptor[] {
  return routes.flatMap((route) => {
    const routeGroups = groups.filter((group) => group.routeId === route.id);

    return routeGroups.flatMap((group) => {
      const wait = waitTimes(group.departures, now);
      if (!wait) return [];

      return [
        {
          key: `${route.id} ${group.destination}`,
          route,
          destination: group.destination,
          wait,
        },
      ];
    });
  });
}

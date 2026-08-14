import type { DepartureGroup, RouteBadge } from '@via/contract';

import { compareRoutes } from '@/lib/route-order';
import { waitTimes, type WaitTimes } from '@/features/departures/model/wait-times';

/** One row of the station's departure board, ready to render. */
export type DepartureRowDescriptor = {
  key: string;
  route: RouteBadge;
  directions: DepartureDirectionDescriptor[];
};

/** One announced direction inside a line's departure-board row. */
export type DepartureDirectionDescriptor = {
  destination: string;
  wait?: WaitTimes;
};

/**
 * The departure board's rows, straight from the groups: each group carries its
 * line's badge, so no network payload has to be consulted to draw one. Lines
 * whose every announced passage has expired do not create placeholder rows.
 */
export function departureRows(groups: DepartureGroup[], now: Date): DepartureRowDescriptor[] {
  return [...Map.groupBy(groups, (group) => group.route.id).values()]
    .flatMap((routeGroups) => {
      const [{ route }] = routeGroups;
      const directions = routeGroups.map((group) => ({
        destination: group.destination,
        wait: waitTimes(group.departures, now),
      }));

      if (directions.every((direction) => !direction.wait)) return [];

      return [{ key: route.id, route, directions }];
    })
    .sort((a, b) => compareRoutes(a.route, b.route));
}

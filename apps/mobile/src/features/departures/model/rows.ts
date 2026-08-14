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

// Hermes does not ship `Map.groupBy`, so the grouping stays hand-rolled here.
function groupByRoute(groups: DepartureGroup[]) {
  const groupsByRoute = new Map<string, DepartureGroup[]>();

  for (const group of groups) {
    const routeGroups = groupsByRoute.get(group.route.id);
    if (routeGroups) {
      routeGroups.push(group);
    } else {
      groupsByRoute.set(group.route.id, [group]);
    }
  }

  return groupsByRoute;
}

/**
 * The departure board's rows, straight from the groups: each group carries its
 * line's badge, so no network payload has to be consulted to draw one. Lines
 * whose every announced passage has expired do not create placeholder rows.
 */
export function departureRows(groups: DepartureGroup[], now: Date): DepartureRowDescriptor[] {
  return [...groupByRoute(groups).values()]
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

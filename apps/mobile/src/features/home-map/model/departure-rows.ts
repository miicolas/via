import type { DepartureGroup, NetworkRoute } from '@via/contract';

/** One row of the station's departure board, ready to render. */
export type DepartureRowDescriptor = {
  key: string;
  route: NetworkRoute;
  /** Absent on a placeholder row — loading, realtime down, or nothing announced. */
  destination?: string;
  /** ISO timestamps, soonest first. Absent on a placeholder row. */
  departures?: string[];
};

/**
 * Pairs each of the station's lines with its departure groups. A line with no
 * group still gets one placeholder row — the board keeps the same layout it
 * had before departures existed, whatever the feed is doing.
 */
export function departureRows(
  routes: NetworkRoute[],
  groups: DepartureGroup[]
): DepartureRowDescriptor[] {
  return routes.flatMap((route) => {
    const routeGroups = groups.filter((group) => group.routeId === route.id);
    if (routeGroups.length === 0) return [{ key: route.id, route }];

    return routeGroups.map((group) => ({
      key: `${route.id} ${group.destination}`,
      route,
      destination: group.destination,
      departures: group.departures,
    }));
  });
}

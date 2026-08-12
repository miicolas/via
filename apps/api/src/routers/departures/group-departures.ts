import { DEPARTURES_PER_GROUP, type DepartureGroup } from '@via/contract';

/** A departure reduced to what grouping needs, whatever source it came from. */
export type DatedDeparture = {
  routeId: string;
  destination: string;
  /** ISO timestamp. */
  at: string;
};

/**
 * Departures → contract groups, the shape a departure board has: one row per
 * line and destination, soonest first, a handful deep. Shared by both sources
 * so a realtime row and a scheduled row can never drift apart in how they
 * bucket, sort or cap — nor in which lines they keep: a station's payload can
 * carry every line calling there (an interchange's RER traffic rides with its
 * metro traffic), so only `stationRouteIds` survive.
 */
export function groupDepartures(
  departures: DatedDeparture[],
  stationRouteIds: string[]
): DepartureGroup[] {
  const served = new Set(stationRouteIds);
  const buckets = new Map<string, DepartureGroup>();

  const sorted = departures
    .filter((departure) => served.has(departure.routeId))
    .sort((a, b) => a.at.localeCompare(b.at));

  for (const departure of sorted) {
    const key = `${departure.routeId} ${departure.destination}`;
    const group = buckets.get(key);
    if (!group) {
      buckets.set(key, {
        routeId: departure.routeId,
        destination: departure.destination,
        departures: [departure.at],
      });
    } else if (group.departures.length < DEPARTURES_PER_GROUP) {
      group.departures.push(departure.at);
    }
  }

  // Stable payload order; the client re-associates by routeId anyway.
  return [...buckets.values()].sort(
    (a, b) => a.routeId.localeCompare(b.routeId) || a.destination.localeCompare(b.destination)
  );
}

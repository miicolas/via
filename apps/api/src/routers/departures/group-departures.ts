import { createHash } from 'node:crypto';

import { DEPARTURES_PER_GROUP, type DepartureGroup, type RouteBadge } from '@via/contract';
import type { DepartureStatus } from '@via/contract';

/** A departure reduced to what grouping needs, whatever source it came from. */
export type DatedDeparture = {
  routeId: string;
  destination: string;
  /** Opaque provider-backed identity, when available. */
  id?: string;
  /** Epoch seconds. */
  scheduledAt?: number;
  /** Epoch seconds. */
  expectedAt?: number;
  /** Signed expected - scheduled difference. */
  delaySeconds?: number;
  status: DepartureStatus;
  providerJourneyRef?: string;
};

/**
 * Departures → contract groups, the shape a departure board has: one row per
 * line and destination, soonest first, a handful deep. Shared by both sources
 * so a realtime row and a scheduled row can never drift apart in how they
 * bucket, sort or cap — nor in which lines they keep: a station's payload can
 * carry every line calling there (an interchange's RER traffic rides with its
 * metro traffic), so only the station's own `routes` survive, and each group
 * carries its line's badge. A line-specific service-day request raises the
 * cap, while the station overview keeps the small default.
 */
export function groupDepartures(
  departures: DatedDeparture[],
  routes: RouteBadge[],
  stationId = '',
  maxDeparturesPerGroup = DEPARTURES_PER_GROUP
): DepartureGroup[] {
  const badgeById = new Map(routes.map((route) => [route.id, route]));
  const buckets = new Map<string, {
    route: RouteBadge;
    destination: string;
    departures: DatedDeparture[];
  }>();

  for (const departure of departures) {
    const route = badgeById.get(departure.routeId);
    if (!route) continue;

    const key = `${departure.routeId} ${departure.destination}`;
    const group = buckets.get(key);
    if (!group) {
      buckets.set(key, {
        route,
        destination: departure.destination,
        departures: [departure],
      });
      continue;
    }

    const insertAt = group.departures.findIndex(
      (candidate) => sortAt(departure) < sortAt(candidate)
    );
    if (insertAt === -1 && group.departures.length >= maxDeparturesPerGroup) continue;

    group.departures.splice(
      insertAt === -1 ? group.departures.length : insertAt,
      0,
      departure
    );
    if (group.departures.length > maxDeparturesPerGroup) group.departures.pop();
  }

  // Stable payload order; the client re-associates by route id anyway.
  return [...buckets.values()]
    .map((group) => {
      const departureItems = group.departures.map((departure) =>
        toDepartureItem(departure, stationId)
      );
      return {
        route: group.route,
        destination: group.destination,
        departures: departureItems.flatMap(legacyDatesFor),
        departureItems,
      };
    })
    .sort(
      (a, b) => a.route.id.localeCompare(b.route.id) || a.destination.localeCompare(b.destination)
    );
}

function sortAt(departure: DatedDeparture): number {
  return departure.expectedAt ?? departure.scheduledAt ?? Number.MAX_SAFE_INTEGER;
}

function toDepartureItem(
  departure: DatedDeparture,
  stationId: string
): DepartureGroup['departureItems'][number] {
  return {
    id:
      departure.id ??
      stableDepartureId({
        stationId,
        routeId: departure.routeId,
        destination: departure.destination,
        scheduledAt: departure.scheduledAt,
        expectedAt: departure.expectedAt,
        providerJourneyRef: departure.providerJourneyRef,
      }),
    ...(departure.scheduledAt === undefined
      ? {}
      : { scheduledAt: isoFromEpochSeconds(departure.scheduledAt) }),
    ...(departure.expectedAt === undefined
      ? {}
      : { expectedAt: isoFromEpochSeconds(departure.expectedAt) }),
    ...(departure.delaySeconds === undefined ? {} : { delaySeconds: departure.delaySeconds }),
    status: departure.status,
  };
}

function legacyDatesFor(item: DepartureGroup['departureItems'][number]): string[] {
  const at = item.expectedAt ?? item.scheduledAt;
  return at ? [at] : [];
}

export function stableDepartureId(input: {
  stationId: string;
  routeId: string;
  destination: string;
  scheduledAt?: number;
  expectedAt?: number;
  providerJourneyRef?: string;
}): string {
  const identity = input.providerJourneyRef
    ? `prim|${input.providerJourneyRef}|${input.stationId}|${input.routeId}`
    : `fallback|${input.stationId}|${input.routeId}|${input.destination}|${input.scheduledAt ?? 'none'}|${input.expectedAt ?? 'none'}`;

  return `departure_${createHash('sha256').update(identity).digest('hex').slice(0, 16)}`;
}

function isoFromEpochSeconds(seconds: number): string {
  return new Date(seconds * 1_000).toISOString();
}

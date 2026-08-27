import { DEPARTURES_PER_GROUP, type DepartureGroup, type RouteBadge } from '@via/contract';

import { groupDepartures, type DatedDeparture } from './group-departures';
import { qualifyDepartureStatus } from './status';
import type { NormalizedVisit } from './prim/parse';

/**
 * PRIM visits → contract groups. What is specific here: trains that have
 * already left are dropped — the grouping itself, filtering included, is the
 * shared machinery.
 */
export function toDepartureGroups(
  visits: NormalizedVisit[],
  stationRoutes: RouteBadge[],
  now: Date,
  stationId = '',
  theoreticalGroups: DepartureGroup[] = [],
  options: DepartureGroupingOptions = {}
): DepartureGroup[] {
  const baselines = scheduleBaselines(theoreticalGroups);
  const usedBaselines = new Set<string>();
  const realtimeDepartures = visits
    .filter((visit) => shouldDisplay(visit, now))
    .map((visit) => {
      const baseline = matchBaseline(visit, baselines, usedBaselines);
      const scheduledAt = visit.scheduledAt ?? baseline?.scheduledAt;
      const timing = qualifyDepartureStatus({
        scheduledAt,
        expectedAt: visit.expectedAt,
        providerStatus: visit.providerStatus,
      });

      return {
        routeId: visit.routeId,
        destination: visit.destination,
        scheduledAt,
        expectedAt: visit.expectedAt,
        providerJourneyRef: visit.providerJourneyRef,
        ...timing,
      };
    });

  const scheduledRemainder = options.includeTheoreticalRemainder
    ? theoreticalRemainder(baselines, usedBaselines, now)
    : [];

  return groupDepartures(
    [...realtimeDepartures, ...scheduledRemainder],
    stationRoutes,
    stationId,
    options.maxDeparturesPerGroup ?? DEPARTURES_PER_GROUP
  );
}

export type DepartureGroupingOptions = {
  maxDeparturesPerGroup?: number;
  includeTheoreticalRemainder?: boolean;
};

const BASELINE_MATCH_WINDOW_SECONDS = 15 * 60;

type ScheduleBaseline = {
  id: string;
  itemId: string;
  routeId: string;
  destination: string;
  scheduledAt: number;
};

function scheduleBaselines(groups: DepartureGroup[]): ScheduleBaseline[] {
  return groups.flatMap((group) =>
    group.departureItems.flatMap((item, index) => {
      if (!item.scheduledAt) return [];

      const milliseconds = Date.parse(item.scheduledAt);
      if (!Number.isFinite(milliseconds)) return [];

      return [{
        id: `${group.route.id}:${group.destination}:${item.id}:${index}`,
        itemId: item.id,
        routeId: group.route.id,
        destination: group.destination,
        scheduledAt: Math.floor(milliseconds / 1_000),
      }];
    })
  );
}

function matchBaseline(
  visit: NormalizedVisit,
  baselines: ScheduleBaseline[],
  usedBaselines: Set<string>
): ScheduleBaseline | undefined {
  const target = visit.scheduledAt ?? visit.expectedAt;
  if (target === undefined) return undefined;

  const destination = normalizedDestination(visit.destination);
  let best: ScheduleBaseline | undefined;
  let bestDistance = Number.POSITIVE_INFINITY;

  for (const baseline of baselines) {
    if (
      usedBaselines.has(baseline.id) ||
      baseline.routeId !== visit.routeId ||
      normalizedDestination(baseline.destination) !== destination
    ) {
      continue;
    }

    const distance = Math.abs(baseline.scheduledAt - target);
    if (distance < bestDistance) {
      best = baseline;
      bestDistance = distance;
    }
  }

  if (!best || bestDistance > BASELINE_MATCH_WINDOW_SECONDS) return undefined;
  usedBaselines.add(best.id);
  return best;
}

function theoreticalRemainder(
  baselines: ScheduleBaseline[],
  usedBaselines: Set<string>,
  now: Date
): DatedDeparture[] {
  const nowSeconds = Math.floor(now.getTime() / 1_000);
  return baselines
    .filter((baseline) => !usedBaselines.has(baseline.id) && baseline.scheduledAt >= nowSeconds)
    .map((baseline) => ({
      routeId: baseline.routeId,
      destination: baseline.destination,
      id: baseline.itemId,
      scheduledAt: baseline.scheduledAt,
      status: 'scheduled' as const,
    }));
}

function normalizedDestination(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLocaleLowerCase('fr-FR')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function shouldDisplay(visit: NormalizedVisit, now: Date): boolean {
  if (visit.providerStatus === 'arrived' || visit.providerStatus === 'departed') {
    return false;
  }

  if (visit.providerStatus === 'cancelled' || visit.providerStatus === 'missed') {
    return true;
  }

  const at = visit.expectedAt ?? visit.scheduledAt;
  if (at === undefined) return false;

  return at >= Math.floor(now.getTime() / 1_000);
}

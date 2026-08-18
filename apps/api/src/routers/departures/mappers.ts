import type { DepartureGroup, RouteBadge } from '@via/contract';

import { groupDepartures } from './group-departures';
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
  theoreticalGroups: DepartureGroup[] = []
): DepartureGroup[] {
  const baselines = scheduleBaselines(theoreticalGroups);
  const usedBaselines = new Set<string>();

  return groupDepartures(
    visits
      .filter((visit) => shouldDisplay(visit, now))
      .map((visit) => {
        const scheduledAt = visit.scheduledAt ?? matchBaseline(
          visit,
          baselines,
          usedBaselines
        );
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
      }),
    stationRoutes,
    stationId
  );
}

const BASELINE_MATCH_WINDOW_SECONDS = 15 * 60;

type ScheduleBaseline = {
  id: string;
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
): number | undefined {
  if (visit.expectedAt === undefined) return undefined;

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

    const distance = Math.abs(baseline.scheduledAt - visit.expectedAt);
    if (distance < bestDistance) {
      best = baseline;
      bestDistance = distance;
    }
  }

  if (!best || bestDistance > BASELINE_MATCH_WINDOW_SECONDS) return undefined;
  usedBaselines.add(best.id);
  return best.scheduledAt;
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

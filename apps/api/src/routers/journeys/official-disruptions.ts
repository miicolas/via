import type { Journey, JourneyInput, JourneySection, JourneysResponse } from '@via/contract';

import type { RedisClient } from '../../redis';
import type { NormalizedDisruption } from '../lines/disruptions/parse';
import {
  getDisruptionsSnapshot,
  type DisruptionsSnapshot,
} from '../lines/disruptions/snapshot';
import type { JourneyDisruptionOverlay } from './service';

const SEVERITY = { attention: 1, disrupted: 2, suspended: 3 } as const;

export function createOfficialJourneyDisruptionOverlay(
  redis: RedisClient,
): JourneyDisruptionOverlay {
  return {
    async apply(response, input, at) {
      const snapshot = await getDisruptionsSnapshot(redis, at);
      return snapshot ? applyOfficialDisruptions(response, input, snapshot) : response;
    },
  };
}

/**
 * Applies the same official PRIM snapshot used by the Lines tab to every
 * planner result. In particular, a GTFS fallback remains useful without
 * pretending its theoretical route is operational through a suspension.
 */
export function applyOfficialDisruptions(
  response: JourneysResponse,
  input: JourneyInput,
  snapshot: DisruptionsSnapshot,
): JourneysResponse {
  const evaluated = response.journeys.map((journey) => evaluate(journey, snapshot.disruptions));
  if (evaluated.every((entry) => entry.severity === 0)) return response;
  const feasible = evaluated.filter((entry) => entry.severity < SEVERITY.suspended);
  const ranked = promoteReasonableUnaffected(feasible);
  const journeys = ranked.map((entry, index) => withQualifier(entry.journey, index));

  return {
    ...response,
    status: journeys.length > 0
      ? 'ready'
      : response.status === 'unavailable' ? 'unavailable' : 'no-route',
    reason: journeys.length === 0 && input.requiresAccessibleStations
      ? 'no-accessible-route'
      : response.reason,
    journeys,
  };
}

function evaluate(journey: Journey, disruptions: NormalizedDisruption[]) {
  const applicable = disruptions.filter((disruption) =>
    journey.sections.some((section) => affectsSection(disruption, section, journey))
  );
  const severity = applicable.reduce(
    (maximum, disruption) => Math.max(maximum, SEVERITY[disruption.severity]),
    0,
  );
  if (severity === 0) return { journey, severity };

  const warnings = [...journey.warnings];
  for (const disruption of applicable) {
    const warning = disruption.title
      ?? disruption.message
      ?? `Perturbation officielle sur ${affectedLineName(journey, disruption)}`;
    if (!warnings.includes(warning)) warnings.push(warning);
  }
  return {
    severity,
    journey: {
      ...journey,
      status: 'disrupted' as const,
      warnings,
    },
  };
}

function affectsSection(
  disruption: NormalizedDisruption,
  section: JourneySection,
  journey: Journey,
): boolean {
  if (section.type !== 'transit' || !section.route) return false;
  if (!disruption.routeIds.includes(section.route.id)) return false;

  const beginsAt = instant(section.departureAt ?? journey.departureAt);
  const endsAt = instant(section.arrivalAt ?? journey.arrivalAt);
  if (beginsAt === null || endsAt === null) return false;
  if (!disruption.periods.some((period) =>
    period.beginsAt <= endsAt && beginsAt <= period.endsAt
  )) return false;

  const impacted = disruption.impactedSections.filter(
    (candidate) => candidate.routeId === section.route?.id,
  );
  if (impacted.length === 0) return true;

  const ids = new Set(section.stops.flatMap((stop) => [stop.id, stop.stationId].filter(Boolean)));
  const names = new Set([
    section.from.name,
    section.to.name,
    ...section.stops.map((stop) => stop.name),
  ].map(normalize));
  return impacted.some((candidate) => {
    const hasFrom = ids.has(candidate.fromStopId) || names.has(normalize(candidate.fromName));
    const hasTo = ids.has(candidate.toStopId) || names.has(normalize(candidate.toName));
    return hasFrom && hasTo;
  });
}

function promoteReasonableUnaffected<T extends { journey: Journey; severity: number }>(
  entries: T[],
): T[] {
  const baseline = entries[0];
  if (!baseline || baseline.severity === 0) return entries;
  const candidate = entries.find((entry) =>
    entry.severity === 0
      && entry.journey.durationSeconds <= baseline.journey.durationSeconds + 15 * 60
      && entry.journey.durationSeconds <= baseline.journey.durationSeconds * 1.25
  );
  return candidate
    ? [candidate, ...entries.filter((entry) => entry !== candidate)]
    : entries;
}

function withQualifier(journey: Journey, index: number): Journey {
  if (index === 0) return { ...journey, qualifier: 'recommended' };
  return journey.qualifier === 'recommended'
    ? { ...journey, qualifier: 'rapid' }
    : journey;
}

function affectedLineName(journey: Journey, disruption: NormalizedDisruption) {
  const route = journey.sections.find((section) =>
    section.route && disruption.routeIds.includes(section.route.id)
  )?.route;
  return route ? `la ligne ${route.shortName}` : 'le trajet';
}

function instant(value: string): number | null {
  const milliseconds = Date.parse(value);
  return Number.isFinite(milliseconds) ? Math.floor(milliseconds / 1_000) : null;
}

function normalize(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .toLocaleLowerCase('fr-FR');
}

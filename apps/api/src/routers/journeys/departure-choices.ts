import type {
  Journey,
  JourneyDepartureChoiceGroup,
  JourneyDepartureChoicesInput,
  JourneyDepartureChoicesResponse,
  JourneySection,
} from '@via/contract';

import { qualifyDepartureStatus } from '../departures/status';
import type { JourneyPlanner } from './service';

type ResolveContext = {
  identity: string;
  signal?: AbortSignal;
};

type SectionCandidate = {
  id: string;
  journey: Journey;
  section: JourneySection;
  source: 'idfm-realtime' | 'gtfs-theoretical' | undefined;
};

type ResolvedGroup = {
  group: JourneyDepartureChoiceGroup;
  next?: SectionCandidate;
  currentRevision?: SectionCandidate;
};

type SectionCandidates = {
  currentRevision?: SectionCandidate;
  next?: SectionCandidate;
  failed?: boolean;
};

export type JourneyDepartureChoicesModule = {
  resolve(
    input: JourneyDepartureChoicesInput,
    context: ResolveContext
  ): Promise<JourneyDepartureChoicesResponse>;
};

export class DepartureChoiceUnavailableError extends Error {}

/**
 * Keeps live passage discovery and journey splicing behind one interface. The
 * app submits the itinerary it is displaying and receives another complete,
 * internally coherent itinerary; no caller ever assembles sections itself.
 */
export function createJourneyDepartureChoicesModule(
  planner: JourneyPlanner,
  clock: { now: () => Date }
): JourneyDepartureChoicesModule {
  const resolveGroups = async (
    input: JourneyDepartureChoicesInput,
    context: ResolveContext
  ): Promise<ResolvedGroup[]> => {
    const transitSections = input.journey.sections
      .map((section, index) => ({ section, index, id: sectionId(input.journey, section, index) }))
      .filter(({ section }) =>
        section.type === 'transit'
        && section.departureAt
        && Date.parse(section.departureAt) > clock.now().getTime()
        && section.route
      );

    return Promise.all(
      transitSections.map(async ({ section, index, id }) => {
        // One provider failure must not erase fresh choices already resolved
        // for the other legs; its group simply keeps the selected service.
        const candidates: SectionCandidates = await sectionCandidates(
          input,
          section,
          index,
          id,
          planner,
          context
        ).catch((error) => {
          if (context.signal?.aborted) throw error;
          return { failed: true as const };
        });
        const { next, currentRevision } = candidates;
        const nextSource = next?.source === 'idfm-realtime'
          ? 'realtime' as const
          : 'theoretical' as const;
        const source = section.timingSource ?? nextSource;
        const fetchedAt = candidates.failed ? undefined : clock.now().toISOString();
        const currentId = departureId(id, section);
        const currentTiming = departureTiming(section, source);
        return {
          group: {
            sectionId: id,
            availability: next ? 'ready' : 'unavailable',
            source,
            fetchedAt,
            choices: [
              {
                id: currentId,
                ...currentTiming,
                source,
                isSelected: true,
              },
              ...(next
                ? [{
                    id: next.id,
                    ...departureTiming(next.section, nextSource),
                    source: nextSource,
                    isSelected: false,
                  }]
                : []),
            ],
          },
          next,
          currentRevision,
        };
      })
    );
  };

  return {
    resolve: async (input, context) => {
      const initial = await resolveGroups(input, context);
      const selection = input.selection;
      if (!selection) {
        const target = initial.find(({ currentRevision }) => currentRevision);
        if (target?.currentRevision) {
          const automaticRevision = target.currentRevision;
          const revised = spliceJourney(
            input.journey,
            target.group.sectionId,
            automaticRevision.journey,
            automaticRevision.section
          );
          const refreshed = await resolveGroups({ ...input, journey: revised }, context);
          return {
            journey: revised,
            generatedAt: clock.now().toISOString(),
            groups: refreshed.map((resolved) => resolved.group),
          };
        }
        return {
          journey: input.journey,
          generatedAt: clock.now().toISOString(),
          groups: initial.map((resolved) => resolved.group),
        };
      }

      const selected = initial.find(
        ({ group }) => group.sectionId === selection.sectionId
      );
      if (!selected || selected.next?.id !== selection.departureId) {
        throw new DepartureChoiceUnavailableError('The selected departure is no longer available');
      }

      const revised = spliceJourney(
        input.journey,
        selection.sectionId,
        selected.next.journey,
        selected.next.section
      );
      if (revised === input.journey) {
        throw new DepartureChoiceUnavailableError('The selected departure has no downstream journey');
      }
      const refreshed = await resolveGroups({ ...input, journey: revised, selection: undefined }, context);
      return {
        journey: revised,
        generatedAt: clock.now().toISOString(),
        groups: refreshed.map((resolved) => resolved.group),
      };
    },
  };
}

async function sectionCandidates(
  input: JourneyDepartureChoicesInput,
  section: JourneySection,
  sectionIndex: number,
  id: string,
  planner: JourneyPlanner,
  context: ResolveContext
): Promise<SectionCandidates> {
  if (!section.departureAt || !section.route) return {};
  const firstStop = section.stops[0];
  const requestedAt = new Date(new Date(section.departureAt).getTime() - 5 * 60_000).toISOString();
  const result = await planner.plan(
    {
      origin: section.from.coordinate,
      destination: input.destination,
      limit: 6,
      requestedAt,
      datetimeRepresents: 'departure',
      requiredModes: input.policy.requiredModes,
      excludedModes: input.policy.excludedModes,
      preferredModes: input.policy.preferredModes,
      requiresAccessibleStations: input.policy.requiresAccessibleStations,
      originStationId: firstStop?.stationId ?? firstStop?.id,
    },
    context
  );

  const originalDeparture = Date.parse(section.departureAt);
  let currentRevision: SectionCandidate | undefined;
  let next: SectionCandidate | undefined;
  for (const journey of result.journeys) {
    const candidate = journey.sections.find(
      (candidateSection) => candidateSection.type === 'transit'
    );
    if (!candidate?.departureAt || !sameTransit(section, candidate)) continue;
    const resolved = {
      id: departureId(id, candidate),
      journey,
      section: candidate,
      source: result.source,
    };
    if (section.serviceId && candidate.serviceId === section.serviceId) {
      if (hasTimingRevision(section, candidate)) currentRevision = resolved;
      continue;
    }
    if (Date.parse(candidate.departureAt) <= originalDeparture) continue;
    if (!next || Date.parse(candidate.departureAt) < Date.parse(next.section.departureAt!)) {
      next = resolved;
    }
  }

  return { currentRevision, next };
}

function hasTimingRevision(current: JourneySection, candidate: JourneySection) {
  return current.departureAt !== candidate.departureAt
    || current.arrivalAt !== candidate.arrivalAt
    || current.scheduledDepartureAt !== candidate.scheduledDepartureAt
    || current.scheduledArrivalAt !== candidate.scheduledArrivalAt;
}

function sameTransit(original: JourneySection, candidate: JourneySection) {
  if (!original.route || !candidate.route) return false;
  const sameRoute = original.route.id === candidate.route.id
    || (
      original.route.mode === candidate.route.mode
      && normalize(original.route.shortName) === normalize(candidate.route.shortName)
    );
  if (!sameRoute) return false;

  const originalAlighting = original.stops.at(-1);
  const candidateAlighting = candidate.stops.at(-1);
  const sameAlighting = Boolean(
    originalAlighting?.id
      && candidateAlighting?.id
      && normalize(originalAlighting.id) === normalize(candidateAlighting.id)
  ) || Boolean(
    originalAlighting?.stationId
      && candidateAlighting?.stationId
      && normalize(originalAlighting.stationId) === normalize(candidateAlighting.stationId)
  ) || normalize(original.to.name) === normalize(candidate.to.name)
    || normalize(originalAlighting?.name) === normalize(candidateAlighting?.name);
  if (!sameAlighting) return false;

  if (!original.direction || !candidate.direction) return true;
  return normalize(original.direction) === normalize(candidate.direction);
}

function spliceJourney(
  current: Journey,
  targetSectionId: string,
  candidateJourney: Journey,
  candidateTransit: JourneySection
): Journey {
  const targetIndex = current.sections.findIndex(
    (section, index) => sectionId(current, section, index) === targetSectionId
  );
  const candidateIndex = candidateJourney.sections.indexOf(candidateTransit);
  if (targetIndex < 0 || candidateIndex < 0) return current;

  const oldPrefix = current.sections.slice(0, targetIndex);
  const removedWaits: JourneySection[] = [];
  while (oldPrefix.at(-1)?.type === 'wait') removedWaits.unshift(oldPrefix.pop()!);
  const prefix = oldPrefix;
  const candidateWait = candidateIndex > 0
    && candidateJourney.sections[candidateIndex - 1]?.type === 'wait'
    ? candidateJourney.sections[candidateIndex - 1]
    : undefined;
  const wait = prefix.length > 0
    ? candidateWait ?? rebuiltWait(prefix, candidateTransit, removedWaits.at(-1), targetSectionId)
    : undefined;
  const suffixSource = [
    ...(wait ? [wait] : []),
    ...candidateJourney.sections.slice(candidateIndex),
  ];
  const suffix = suffixSource.map((section, index) => ({
    ...section,
    id: section === candidateTransit
      ? targetSectionId
      : section.id ?? `${targetSectionId}:revised:${index}`,
  }));
  const sections = [...prefix, ...suffix];
  const transitCount = sections.filter((section) => section.type === 'transit').length;
  const departureAt = prefix.length > 0
    ? current.departureAt
    : candidateTransit.departureAt ?? candidateJourney.departureAt;
  const arrivalAt = candidateJourney.arrivalAt;

  return {
    ...current,
    durationSeconds: Math.max(0, Math.round((Date.parse(arrivalAt) - Date.parse(departureAt)) / 1_000)),
    walkingDurationSeconds: sections
      .filter((section) => section.type === 'walk')
      .reduce((sum, section) => sum + section.durationSeconds, 0),
    transferCount: Math.max(0, transitCount - 1),
    arrivalAt,
    status:
      current.status === 'disrupted' || candidateJourney.status === 'disrupted'
        ? 'disrupted'
        : candidateJourney.status,
    warnings: [...new Set([...current.warnings, ...candidateJourney.warnings])],
    accessibility: candidateJourney.accessibility ?? current.accessibility,
    peak: candidateJourney.peak ?? current.peak,
    sections,
  };
}

function rebuiltWait(
  prefix: JourneySection[],
  transit: JourneySection,
  previousWait: JourneySection | undefined,
  targetSectionId: string
): JourneySection | undefined {
  if (!transit.departureAt) return undefined;
  const previous = prefix.at(-1);
  const startsAt = previousWait?.departureAt ?? previous?.arrivalAt;
  if (!startsAt) return undefined;
  const durationSeconds = Math.max(
    0,
    Math.round((Date.parse(transit.departureAt) - Date.parse(startsAt)) / 1_000)
  );
  if (durationSeconds === 0) return undefined;
  return {
    id: previousWait?.id ?? `${targetSectionId}:wait`,
    type: 'wait',
    durationSeconds,
    from: transit.from,
    to: transit.from,
    departureAt: startsAt,
    arrivalAt: transit.departureAt,
    geometry: [],
    stops: [],
  };
}

function sectionId(journey: Journey, section: JourneySection, index: number) {
  return section.id ?? `${journey.id}:${index}`;
}

function departureId(sectionId: string, section: JourneySection) {
  return `departure:${sectionId}:${section.serviceId ?? section.scheduledDepartureAt ?? section.departureAt ?? 'unknown'}`;
}

/**
 * The same qualification the departure board applies, so one vehicle cannot be
 * "a l'heure" on the board and "+1 min" in a journey choice card. That means
 * the shared 120 s threshold and the shared refusal to manufacture `on_time`
 * without a scheduled time — not a second rule with its own cutoff.
 *
 * A theoretical feed reports no delay at all, so it stays `scheduled`.
 */
function departureTiming(
  section: JourneySection,
  source: 'realtime' | 'theoretical'
) {
  const scheduledAt = section.scheduledDepartureAt ?? section.departureAt;
  const expectedAt = source === 'realtime' ? section.departureAt : undefined;
  if (section.departureStatus) {
    return { scheduledAt, expectedAt, status: section.departureStatus };
  }
  if (source === 'theoretical') {
    return { scheduledAt, expectedAt, status: 'scheduled' as const };
  }
  const { status } = qualifyDepartureStatus({
    scheduledAt: scheduledAt ? Math.floor(Date.parse(scheduledAt) / 1_000) : undefined,
    expectedAt: expectedAt ? Math.floor(Date.parse(expectedAt) / 1_000) : undefined,
  });
  return { scheduledAt, expectedAt, status };
}

function normalize(value?: string) {
  return (value ?? '')
    .normalize('NFD')
    .replaceAll(/\p{Diacritic}/gu, '')
    .replaceAll(/[^a-zA-Z0-9]/g, '')
    .toLowerCase();
}

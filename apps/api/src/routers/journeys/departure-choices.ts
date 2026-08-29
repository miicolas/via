import type {
  DepartureStatus,
  Journey,
  JourneyDepartureChoice,
  JourneyDepartureChoiceGroup,
  JourneyDepartureChoicesInput,
  JourneyDepartureChoicesResponse,
  JourneySection,
} from '@via/contract';

import { qualifyDepartureStatus } from '../departures/status';
import type { CachedStationSnapshot } from '../departures/cache';
import type { JourneyPlanner } from './service';
import { selectTimetableRuns, type TimetableRunReader } from './timetable-runs';

type ResolveContext = {
  identity: string;
  signal?: AbortSignal;
};

type SectionCandidate = {
  journey: Journey;
  section: JourneySection;
};

type Alternative = {
  id: string;
  departureAt: string;
  arrivalAt?: string;
  serviceId?: string;
  headsign?: string;
  scheduledAt?: string;
  scheduledArrivalAt?: string;
  expectedAt?: string;
  status: DepartureStatus;
  source: 'realtime' | 'theoretical';
};

type ResolvedGroup = {
  group: JourneyDepartureChoiceGroup;
  section: JourneySection;
  alternatives: Alternative[];
};

export type StationDepartureSnapshotReader = (
  stationId: string,
) => Promise<CachedStationSnapshot | null>;

type JourneyDepartureChoicesDependencies = {
  readTimetableRuns?: TimetableRunReader;
  readStationSnapshot?: StationDepartureSnapshotReader;
};

export type JourneyDepartureChoicesModule = {
  resolve(
    input: JourneyDepartureChoicesInput,
    context: ResolveContext
  ): Promise<JourneyDepartureChoicesResponse>;
};

export class DepartureChoiceUnavailableError extends Error {}

/** How many passages either side of the held one the traveller may step through. */
const CHOICES_PER_SIDE = 3;
/** How far the timetable is scanned around the held departure. */
const TIMETABLE_WINDOW_MS = 90 * 60_000;
const REALTIME_MATCH_WINDOW_SECONDS = 15 * 60;

/**
 * Keeps local passage discovery, opportunistic realtime enrichment and journey
 * splicing behind one interface. Passive reads never invoke the planner.
 */
export function createJourneyDepartureChoicesModule(
  planner: JourneyPlanner,
  clock: { now: () => Date },
  dependencies: JourneyDepartureChoicesDependencies = {},
): JourneyDepartureChoicesModule {
  const readTimetableRuns = dependencies.readTimetableRuns ?? selectTimetableRuns;
  const readStationSnapshot = dependencies.readStationSnapshot ?? (async () => null);
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
        const stationId = section.stops[0]?.stationId ?? section.stops[0]?.id;
        const [scheduled, snapshot] = await Promise.all([
          timetableAlternatives(
            section,
            id,
            readTimetableRuns,
            clock.now(),
          ).catch((error) => {
            if (context.signal?.aborted) throw error;
            return [];
          }),
          stationId
            ? readStationSnapshot(stationId).catch((error) => {
                if (context.signal?.aborted) throw error;
                return null;
              })
            : Promise.resolve(null),
        ]);

        const currentId = departureId(id, section);
        const localCurrent = alternativeFromSection(id, section);
        const enriched = enrichWithSnapshot(
          section.route!.id,
          [localCurrent, ...scheduled],
          snapshot,
        );
        const current = enriched[0]!;
        const source = current.source === 'realtime'
          || enriched.some((alternative) => alternative.source === 'realtime')
          ? ('realtime' as const)
          : ('theoretical' as const);
        const currentDepartureAt = current.departureAt;

        const alternatives = stepRange(
          merge(enriched.slice(1), currentId),
          Date.parse(currentDepartureAt),
          boardingReadyAt(input.journey.sections, index, clock.now()),
        );
        const fetchedAt = snapshot && enriched.some(
          (alternative) => alternative.source === 'realtime',
        )
          ? new Date(snapshot.fetchedAt * 1_000).toISOString()
          : undefined;

        // Chronological, so the row reads as a timeline the traveller steps
        // along: the services before, the one held, the ones after.
        const choices: JourneyDepartureChoice[] = [
          ...alternatives
            .filter((alternative) => Date.parse(alternative.departureAt) < Date.parse(currentDepartureAt))
            .map(toChoice),
          {
            id: currentId,
            scheduledAt: current.scheduledAt,
            expectedAt: current.expectedAt,
            status: current.status,
            source: current.source,
            isSelected: true,
          },
          ...alternatives
            .filter((alternative) => Date.parse(alternative.departureAt) >= Date.parse(currentDepartureAt))
            .map(toChoice),
        ];

        return {
          group: {
            sectionId: id,
            availability: alternatives.length > 0 ? ('ready' as const) : ('unavailable' as const),
            source,
            fetchedAt,
            choices,
          },
          section,
          alternatives,
        };
      }),
    );
  };

  const respond = (journey: Journey, groups: ResolvedGroup[]): JourneyDepartureChoicesResponse => ({
    journey,
    generatedAt: clock.now().toISOString(),
    groups: groups.map((resolved) => resolved.group),
  });

  return {
    resolve: async (input, context) => {
      const initial = await resolveGroups(input, context);
      const selection = input.selection;
      if (!selection) return respond(input.journey, initial);

      const selected = initial.find(({ group }) => group.sectionId === selection.sectionId);
      const chosen = selected?.alternatives.find(
        (alternative) => alternative.id === selection.departureId
      );
      if (!selected || !chosen) {
        throw new DepartureChoiceUnavailableError('The selected departure is no longer available');
      }

      const candidate = scheduledCandidateFromCurrent(
        input.journey,
        selected.section,
        selection.sectionId,
        chosen,
      ) ?? (await scheduledCandidateWithReplannedDownstream(
        input,
        selected.section,
        selection.sectionId,
        chosen,
        planner,
        context,
      ).catch((error) => {
        if (context.signal?.aborted) throw error;
        return undefined;
      }));
      if (!candidate) {
        throw new DepartureChoiceUnavailableError('The selected departure is no longer available');
      }

      const revised = spliceJourney(
        input.journey,
        selection.sectionId,
        candidate.journey,
        candidate.section
      );
      if (revised === input.journey) {
        throw new DepartureChoiceUnavailableError('The selected departure has no downstream journey');
      }
      const refreshed = await resolveGroups(
        { ...input, journey: revised, selection: undefined },
        context
      );
      return respond(revised, refreshed);
    },
  };
}

/**
 * The alternatives around the held departure, nearest first, capped either
 * side. Chronological order is read off the departure instants rather than the
 * clock, so a delayed later service still lands after the one held.
 */
function stepRange(alternatives: Alternative[], currentDepartureAt: number, readyAt: number) {
  const catchable = alternatives.filter(
    (alternative) => Date.parse(alternative.departureAt) > readyAt
  );
  const before = catchable
    .filter((alternative) => Date.parse(alternative.departureAt) < currentDepartureAt)
    .slice(-CHOICES_PER_SIDE);
  const after = catchable
    .filter((alternative) => Date.parse(alternative.departureAt) >= currentDepartureAt)
    .slice(0, CHOICES_PER_SIDE);
  return [...before, ...after];
}

/**
 * The earliest a passage of this leg could be boarded: not simply "after now",
 * but after the traveller has actually reached the platform. Offering the train
 * leaving in two minutes when five minutes of walking still stand in the way is
 * a choice they cannot take.
 */
function boardingReadyAt(sections: JourneySection[], index: number, now: Date) {
  for (let previous = index - 1; previous >= 0; previous -= 1) {
    const section = sections[previous]!;
    // A wait *is* time on the platform, so it does not push the floor out.
    if (section.type === 'wait') continue;
    return Math.max(now.getTime(), section.arrivalAt ? Date.parse(section.arrivalAt) : 0);
  }
  return now.getTime();
}

function merge(scheduled: Alternative[], currentId: string): Alternative[] {
  const byId = new Map<string, Alternative>();
  for (const alternative of scheduled) byId.set(alternative.id, alternative);
  byId.delete(currentId);
  return [...byId.values()].sort((a, b) => Date.parse(a.departureAt) - Date.parse(b.departureAt));
}

function toChoice(alternative: Alternative): JourneyDepartureChoice {
  return {
    id: alternative.id,
    scheduledAt: alternative.scheduledAt,
    expectedAt: alternative.expectedAt,
    status: alternative.status,
    source: alternative.source,
    isSelected: false,
  };
}

/** The other runs of this line between the same two stops, straight from the schedule. */
async function timetableAlternatives(
  section: JourneySection,
  id: string,
  readTimetableRuns: TimetableRunReader,
  now: Date
): Promise<Alternative[]> {
  if (!section.departureAt || !section.route) return [];
  const boarding = section.stops[0];
  const alighting = section.stops.at(-1);
  if (!boarding || !alighting || section.stops.length < 2) return [];

  const anchor = Date.parse(section.departureAt);
  const runs = await readTimetableRuns({
    routeId: section.route.id,
    boardingStopIds: stopIdentifiers(boarding),
    alightingStopIds: stopIdentifiers(alighting),
    from: new Date(Math.max(now.getTime(), anchor - TIMETABLE_WINDOW_MS)),
    to: new Date(anchor + TIMETABLE_WINDOW_MS),
  });

  return runs.map((run) => ({
    id: `departure:${id}:${canonicalServiceId(run.tripId)}`,
    departureAt: run.departureAt,
    arrivalAt: run.arrivalAt,
    serviceId: canonicalServiceId(run.tripId),
    headsign: run.headsign,
    scheduledAt: run.departureAt,
    scheduledArrivalAt: run.arrivalAt,
    status: 'scheduled' as const,
    source: 'theoretical' as const,
  }));
}

function stopIdentifiers(stop: { id: string; stationId?: string }) {
  return [stop.stationId, stop.id].filter((value): value is string => Boolean(value));
}

/**
 * A timetable run can be valid even when a Pareto planner omits it. If it still
 * reaches the already-held connection, keep that coherent suffix and retime the
 * selected leg from the schedule instead of silently substituting another run.
 */
function scheduledCandidateFromCurrent(
  journey: Journey,
  section: JourneySection,
  id: string,
  alternative: Alternative
): SectionCandidate | undefined {
  if (!alternative.arrivalAt || !alternative.serviceId) return undefined;
  const targetIndex = journey.sections.findIndex(
    (candidate, index) => sectionId(journey, candidate, index) === id
  );
  if (targetIndex < 0) return undefined;

  const selected = retimeScheduledSection(section, alternative);
  const suffix = preservedDownstream(
    journey.sections.slice(targetIndex + 1),
    selected.arrivalAt!
  );
  if (!suffix) return undefined;

  const sections = [selected, ...suffix];
  const arrivalAt = sections.at(-1)?.arrivalAt ?? selected.arrivalAt!;
  const transitCount = sections.filter((candidate) => candidate.type === 'transit').length;
  return {
    section: selected,
    journey: {
      ...journey,
      departureAt: selected.departureAt!,
      arrivalAt,
      durationSeconds: Math.max(
        0,
        Math.round((Date.parse(arrivalAt) - Date.parse(selected.departureAt!)) / 1_000)
      ),
      walkingDurationSeconds: sections
        .filter((candidate) => candidate.type === 'walk')
        .reduce((sum, candidate) => sum + candidate.durationSeconds, 0),
      transferCount: Math.max(0, transitCount - 1),
      sections,
    },
  };
}

/**
 * When the chosen run misses the old connection, start a new plan at its
 * alighting stop. The selected run stays fixed; only the journey after it is
 * delegated back to the planner.
 */
async function scheduledCandidateWithReplannedDownstream(
  input: JourneyDepartureChoicesInput,
  section: JourneySection,
  id: string,
  alternative: Alternative,
  planner: JourneyPlanner,
  context: ResolveContext
): Promise<SectionCandidate | undefined> {
  if (!alternative.arrivalAt || !alternative.serviceId) return undefined;
  const alighting = section.stops.at(-1);
  if (!alighting) return undefined;

  const result = await planner.plan(
    {
      origin: alighting.coordinate,
      destination: input.destination,
      limit: 6,
      requestedAt: alternative.arrivalAt,
      datetimeRepresents: 'departure',
      requiredModes: input.policy.requiredModes,
      excludedModes: input.policy.excludedModes,
      preferredModes: input.policy.preferredModes,
      requiresAccessibleStations: input.policy.requiresAccessibleStations,
      requiresOperationalElevators: input.policy.requiresOperationalElevators,
      originStationId: alighting.stationId ?? alighting.id,
    },
    context
  );
  const arrival = Date.parse(alternative.arrivalAt);
  const downstream = result.journeys.find(
    (journey) => Date.parse(journey.departureAt) >= arrival
  );
  if (!downstream) return undefined;

  const selected = retimeScheduledSection(section, alternative);
  const sections: JourneySection[] = [selected];
  const downstreamDeparture = Date.parse(downstream.departureAt);
  if (downstreamDeparture > arrival) {
    const interchange = { name: alighting.name, coordinate: alighting.coordinate };
    sections.push({
      id: `${id}:downstream-wait`,
      type: 'wait',
      durationSeconds: Math.round((downstreamDeparture - arrival) / 1_000),
      from: interchange,
      to: interchange,
      departureAt: alternative.arrivalAt,
      arrivalAt: downstream.departureAt,
      geometry: [],
      stops: [],
    });
  }
  sections.push(...downstream.sections.map((candidate, index) => ({
    ...candidate,
    id: `${id}:downstream:${index}`,
  })));
  const arrivalAt = downstream.arrivalAt;
  const transitCount = sections.filter((candidate) => candidate.type === 'transit').length;
  return {
    section: selected,
    journey: {
      ...downstream,
      // This candidate is only the selected leg plus a plan from its alighting
      // stop. The downstream total is not the fare of the composite journey.
      fare: undefined,
      departureAt: selected.departureAt!,
      durationSeconds: Math.max(
        0,
        Math.round((Date.parse(arrivalAt) - Date.parse(selected.departureAt!)) / 1_000)
      ),
      walkingDurationSeconds: sections
        .filter((candidate) => candidate.type === 'walk')
        .reduce((sum, candidate) => sum + candidate.durationSeconds, 0),
      transferCount: Math.max(0, transitCount - 1),
      sections,
    },
  };
}

function retimeScheduledSection(section: JourneySection, alternative: Alternative): JourneySection {
  const departureAt = alternative.departureAt;
  const arrivalAt = alternative.arrivalAt!;
  const stops = section.stops.map((stop, index) => ({
    ...stop,
    arrivalAt: retimeInstant(stop.arrivalAt, section, departureAt, arrivalAt),
    departureAt: retimeInstant(stop.departureAt, section, departureAt, arrivalAt),
    ...(index === 0 ? { departureAt } : {}),
    ...(index === section.stops.length - 1 ? { arrivalAt } : {}),
  }));
  return {
    ...section,
    durationSeconds: Math.max(
      0,
      Math.round((Date.parse(arrivalAt) - Date.parse(departureAt)) / 1_000)
    ),
    departureAt,
    arrivalAt,
    scheduledDepartureAt: alternative.scheduledAt ?? departureAt,
    scheduledArrivalAt: alternative.scheduledArrivalAt ?? arrivalAt,
    serviceId: alternative.serviceId,
    timingSource: alternative.source,
    departureStatus: alternative.status,
    stops,
  };
}

function retimeInstant(
  instant: string | undefined,
  section: JourneySection,
  departureAt: string,
  arrivalAt: string
) {
  if (!instant || !section.departureAt || !section.arrivalAt) return instant;
  const originalStart = Date.parse(section.departureAt);
  const originalDuration = Date.parse(section.arrivalAt) - originalStart;
  const ratio = originalDuration > 0
    ? Math.min(1, Math.max(0, (Date.parse(instant) - originalStart) / originalDuration))
    : 0;
  const targetStart = Date.parse(departureAt);
  const targetDuration = Date.parse(arrivalAt) - targetStart;
  return new Date(targetStart + targetDuration * ratio).toISOString();
}

function preservedDownstream(
  sections: JourneySection[],
  selectedArrivalAt: string
): JourneySection[] | undefined {
  const nextTransitIndex = sections.findIndex((section) => section.type === 'transit');
  if (nextTransitIndex < 0) return retimeTrailingSections(sections, selectedArrivalAt);

  const nextTransit = sections[nextTransitIndex]!;
  if (!nextTransit.departureAt) return undefined;
  const connectors = sections.slice(0, nextTransitIndex);
  const movement = connectors.filter((section) => section.type !== 'wait');
  let cursor = Date.parse(selectedArrivalAt);
  const nextDeparture = Date.parse(nextTransit.departureAt);
  const movementDuration = movement.reduce(
    (sum, section) => sum + section.durationSeconds * 1_000,
    0
  );
  if (cursor + movementDuration > nextDeparture) return undefined;

  const rebuilt = movement.map((section) => {
    const departureAt = new Date(cursor).toISOString();
    cursor += section.durationSeconds * 1_000;
    return {
      ...section,
      departureAt,
      arrivalAt: new Date(cursor).toISOString(),
    };
  });
  if (cursor < nextDeparture) {
    const previousWait = connectors.find((section) => section.type === 'wait');
    rebuilt.push({
      ...(previousWait ?? {
        id: `${nextTransit.id ?? 'connection'}:wait`,
        type: 'wait' as const,
        from: nextTransit.from,
        to: nextTransit.from,
        geometry: [],
        stops: [],
      }),
      durationSeconds: Math.round((nextDeparture - cursor) / 1_000),
      departureAt: new Date(cursor).toISOString(),
      arrivalAt: nextTransit.departureAt,
    });
  }
  return [...rebuilt, ...sections.slice(nextTransitIndex)];
}

function retimeTrailingSections(sections: JourneySection[], startsAt: string) {
  let cursor = Date.parse(startsAt);
  return sections.map((section) => {
    const departureAt = new Date(cursor).toISOString();
    cursor += section.durationSeconds * 1_000;
    return {
      ...section,
      departureAt,
      arrivalAt: new Date(cursor).toISOString(),
    };
  });
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
    // A retimed unchanged route carries the original full fare. A partially
    // replanned route explicitly clears it because neither subtotal is exact.
    fare: candidateJourney.fare,
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

function alternativeFromSection(id: string, section: JourneySection): Alternative {
  const source = section.timingSource === 'theoretical' ? 'theoretical' : 'realtime';
  const timing = departureTiming(section, source);
  return {
    id: departureId(id, section),
    departureAt: section.departureAt!,
    arrivalAt: section.arrivalAt,
    serviceId: section.serviceId ? canonicalServiceId(section.serviceId) : undefined,
    headsign: section.direction,
    scheduledArrivalAt: section.scheduledArrivalAt
      ?? (source === 'theoretical' ? section.arrivalAt : undefined),
    ...timing,
    source,
  };
}

function enrichWithSnapshot(
  routeId: string,
  alternatives: Alternative[],
  snapshot: CachedStationSnapshot | null,
): Alternative[] {
  if (!snapshot) return alternatives;

  const matchedVisits = new Map<number, number>();
  const usedVisits = new Set<number>();

  // Identity is stronger than timing and destination. Resolve every identity
  // match before allowing a fallback to consume one of those visits.
  alternatives.forEach((alternative, alternativeIndex) => {
    if (!alternative.serviceId) return;
    const visitIndex = snapshot.visits.findIndex((visit, index) =>
      !usedVisits.has(index)
      && visit.routeId === routeId
      && Boolean(visit.providerJourneyRef)
      && canonicalServiceId(visit.providerJourneyRef!) === alternative.serviceId
    );
    if (visitIndex < 0) return;
    usedVisits.add(visitIndex);
    matchedVisits.set(alternativeIndex, visitIndex);
  });

  const fallbackCandidates: Array<{
    alternativeIndex: number;
    visitIndex: number;
    distance: number;
  }> = [];
  alternatives.forEach((alternative, alternativeIndex) => {
    if (matchedVisits.has(alternativeIndex) || !alternative.scheduledAt) return;
    const scheduledAt = Math.floor(Date.parse(alternative.scheduledAt) / 1_000);
    if (!Number.isFinite(scheduledAt)) return;

    snapshot.visits.forEach((visit, visitIndex) => {
      if (
        usedVisits.has(visitIndex)
        || visit.routeId !== routeId
        || normalize(visit.destination) !== normalize(alternative.headsign)
      ) {
        return;
      }
      const visitAt = visit.scheduledAt ?? visit.expectedAt;
      if (visitAt === undefined) return;
      const distance = Math.abs(visitAt - scheduledAt);
      if (distance <= REALTIME_MATCH_WINDOW_SECONDS) {
        fallbackCandidates.push({ alternativeIndex, visitIndex, distance });
      }
    });
  });
  fallbackCandidates.sort((left, right) => left.distance - right.distance);
  for (const candidate of fallbackCandidates) {
    if (
      matchedVisits.has(candidate.alternativeIndex)
      || usedVisits.has(candidate.visitIndex)
    ) {
      continue;
    }
    matchedVisits.set(candidate.alternativeIndex, candidate.visitIndex);
    usedVisits.add(candidate.visitIndex);
  }

  return alternatives.map((alternative, index) => {
    const visitIndex = matchedVisits.get(index);
    if (visitIndex === undefined) return alternative;
    const visit = snapshot.visits[visitIndex]!;
    const scheduledAt = alternative.scheduledAt
      ? Math.floor(Date.parse(alternative.scheduledAt) / 1_000)
      : visit.scheduledAt;
    const expectedAt = visit.expectedAt;
    const status = qualifyDepartureStatus({
      scheduledAt,
      expectedAt,
      providerStatus: visit.providerStatus,
    }).status;
    const delaySeconds = scheduledAt !== undefined && expectedAt !== undefined
      ? expectedAt - scheduledAt
      : 0;
    const expectedIso = expectedAt === undefined
      ? undefined
      : new Date(expectedAt * 1_000).toISOString();
    const scheduledArrival = alternative.scheduledArrivalAt ?? alternative.arrivalAt;
    const arrivalAt = scheduledArrival && expectedAt !== undefined
      ? new Date(Date.parse(scheduledArrival) + delaySeconds * 1_000).toISOString()
      : alternative.arrivalAt;

    return {
      ...alternative,
      departureAt: expectedIso ?? alternative.scheduledAt ?? alternative.departureAt,
      arrivalAt,
      expectedAt: expectedIso,
      status,
      source: 'realtime' as const,
    };
  });
}

function sectionId(journey: Journey, section: JourneySection, index: number) {
  return section.id ?? `${journey.id}:${index}`;
}

function departureId(sectionId: string, section: JourneySection) {
  const identity = section.serviceId
    ? canonicalServiceId(section.serviceId)
    : section.scheduledDepartureAt ?? section.departureAt ?? 'unknown';
  return `departure:${sectionId}:${identity}`;
}

/** Navitia namespaces the same GTFS trip id as a vehicle journey. */
function canonicalServiceId(serviceId: string) {
  return serviceId.replace(/^(?:vehicle_journey|trip):/, '');
}

/**
 * The same qualification the departure board applies, so one vehicle cannot be
 * "a l'heure" on the board and "+1 min" in a journey choice card. That means
 * the shared 120 s threshold and the shared refusal to manufacture `on_time`
 * without a scheduled time — not a second rule with its own cutoff.
 *
 * A schedule-only feed reports no delay at all, so it stays `scheduled`.
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

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
import type { JourneyPlanner } from './service';
import { selectTimetableRuns, type TimetableRunReader } from './timetable-runs';

type ResolveContext = {
  identity: string;
  signal?: AbortSignal;
};

/** An alternative the planner has already turned into a complete itinerary. */
type SectionCandidate = {
  id: string;
  journey: Journey;
  section: JourneySection;
  source: 'idfm-realtime' | 'gtfs-theoretical' | undefined;
};

/**
 * One other passage on offer. The timetable can name a passage long before
 * anything has planned around it, so `candidate` is optional: a choice the
 * traveller never picks is never planned.
 */
type Alternative = {
  id: string;
  departureAt: string;
  arrivalAt?: string;
  serviceId?: string;
  scheduledAt?: string;
  expectedAt?: string;
  status: DepartureStatus;
  source: 'realtime' | 'theoretical';
  candidate?: SectionCandidate;
};

type ResolvedGroup = {
  group: JourneyDepartureChoiceGroup;
  section: JourneySection;
  alternatives: Alternative[];
  currentRevision?: SectionCandidate;
};

type SectionCandidates = {
  currentRevision?: SectionCandidate;
  /** Every matching service, chronological, the held one excluded. */
  matches: SectionCandidate[];
  failed?: boolean;
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

/**
 * Keeps live passage discovery and journey splicing behind one interface. The
 * app submits the itinerary it is displaying and receives another complete,
 * internally coherent itinerary; no caller ever assembles sections itself.
 */
export function createJourneyDepartureChoicesModule(
  planner: JourneyPlanner,
  clock: { now: () => Date },
  readTimetableRuns: TimetableRunReader = selectTimetableRuns
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
        const planned: SectionCandidates = await plannedCandidates(
          input,
          section,
          id,
          planner,
          clock.now(),
          context
        ).catch((error) => {
          if (context.signal?.aborted) throw error;
          return { matches: [], failed: true as const };
        });

        const scheduled = await timetableAlternatives(
          section,
          id,
          readTimetableRuns,
          clock.now()
        ).catch((error) => {
          if (context.signal?.aborted) throw error;
          return [];
        });

        const source = section.timingSource ?? sourceOf(planned.matches[0]?.source);
        const currentId = departureId(id, section);
        const currentTiming = departureTiming(section, source);
        const currentDepartureAt = section.departureAt!;

        const alternatives = stepRange(
          merge(planned.matches, scheduled, currentId),
          Date.parse(currentDepartureAt),
          boardingReadyAt(input.journey.sections, index, clock.now())
        );
        const fetchedAt = planned.failed && scheduled.length === 0
          ? undefined
          : clock.now().toISOString();

        // Chronological, so the row reads as a timeline the traveller steps
        // along: the services before, the one held, the ones after.
        const choices: JourneyDepartureChoice[] = [
          ...alternatives
            .filter((alternative) => Date.parse(alternative.departureAt) < Date.parse(currentDepartureAt))
            .map(toChoice),
          {
            id: currentId,
            ...currentTiming,
            source,
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
          currentRevision: planned.currentRevision,
        };
      })
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
          return respond(revised, refreshed);
        }
        return respond(input.journey, initial);
      }

      const selected = initial.find(({ group }) => group.sectionId === selection.sectionId);
      const chosen = selected?.alternatives.find(
        (alternative) => alternative.id === selection.departureId
      );
      if (!selected || !chosen) {
        throw new DepartureChoiceUnavailableError('The selected departure is no longer available');
      }

      // A choice read off the timetable has no itinerary yet: only the one the
      // traveller actually picks is worth planning.
      const candidate = chosen.candidate
        ?? (await materialise(input, selected.section, selection.sectionId, chosen, planner, context));
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

/** Planned alternatives win over scheduled ones: they already carry a journey. */
function merge(
  planned: SectionCandidate[],
  scheduled: Alternative[],
  currentId: string
): Alternative[] {
  const byId = new Map<string, Alternative>();
  for (const alternative of scheduled) byId.set(alternative.id, alternative);
  for (const candidate of planned) byId.set(candidate.id, alternativeFor(candidate));
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
    scheduledAt: run.departureAt,
    status: 'scheduled' as const,
    source: 'theoretical' as const,
  }));
}

function stopIdentifiers(stop: { id: string; stationId?: string }) {
  return [stop.stationId, stop.id].filter((value): value is string => Boolean(value));
}

/**
 * Plans the one run the traveller picked. Anchored a minute before it leaves
 * with the boarding station pinned, an exact trip-id match wins. If the planner
 * prunes that run, the schedule holds it fixed and only the downstream is
 * preserved or replanned.
 */
async function materialise(
  input: JourneyDepartureChoicesInput,
  section: JourneySection,
  id: string,
  alternative: Alternative,
  planner: JourneyPlanner,
  context: ResolveContext
): Promise<SectionCandidate | undefined> {
  const target = Date.parse(alternative.departureAt);
  const result = await planner.plan(
    {
      origin: section.from.coordinate,
      destination: input.destination,
      limit: 6,
      requestedAt: new Date(target - 60_000).toISOString(),
      datetimeRepresents: 'departure',
      requiredModes: input.policy.requiredModes,
      excludedModes: input.policy.excludedModes,
      preferredModes: input.policy.preferredModes,
      requiresAccessibleStations: input.policy.requiresAccessibleStations,
      originStationId: section.stops[0]?.stationId ?? section.stops[0]?.id,
    },
    context
  );

  for (const journey of result.journeys) {
    const candidate = journey.sections.find((value) => value.type === 'transit');
    if (!candidate?.departureAt || !sameTransit(section, candidate)) continue;
    const resolved = {
      id: departureId(id, candidate),
      journey,
      section: candidate,
      source: result.source,
    };
    if (resolved.id === alternative.id) return resolved;
  }
  return scheduledCandidateFromCurrent(input.journey, section, id, alternative)
    ?? (await scheduledCandidateWithReplannedDownstream(
      input,
      section,
      id,
      alternative,
      planner,
      context
    ));
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
    id: departureId(id, selected),
    section: selected,
    source: 'gtfs-theoretical',
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
    id: departureId(id, selected),
    section: selected,
    source: 'gtfs-theoretical',
    journey: {
      ...downstream,
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
    scheduledDepartureAt: departureAt,
    scheduledArrivalAt: arrivalAt,
    serviceId: alternative.serviceId,
    timingSource: 'theoretical',
    departureStatus: 'scheduled',
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

async function plannedCandidates(
  input: JourneyDepartureChoicesInput,
  section: JourneySection,
  id: string,
  planner: JourneyPlanner,
  now: Date,
  context: ResolveContext
): Promise<SectionCandidates> {
  if (!section.departureAt || !section.route) return { matches: [] };
  const firstStop = section.stops[0];
  const originalDeparture = Date.parse(section.departureAt);

  const scan = async (
    requestedAt: string,
    datetimeRepresents: 'departure' | 'arrival' = 'departure'
  ): Promise<SectionCandidates> => {
    const result = await planner.plan(
      {
        origin: section.from.coordinate,
        destination: input.destination,
        limit: 6,
        requestedAt,
        datetimeRepresents,
        requiredModes: input.policy.requiredModes,
        excludedModes: input.policy.excludedModes,
        preferredModes: input.policy.preferredModes,
        requiresAccessibleStations: input.policy.requiresAccessibleStations,
        originStationId: firstStop?.stationId ?? firstStop?.id,
      },
      context
    );

    let currentRevision: SectionCandidate | undefined;
    const matches: SectionCandidate[] = [];
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
      if (
        section.serviceId
        && candidate.serviceId
        && canonicalServiceId(candidate.serviceId) === canonicalServiceId(section.serviceId)
      ) {
        if (hasTimingRevision(section, candidate)) currentRevision = resolved;
        continue;
      }
      // A service that has already left is not a choice, so stepping back can
      // only ever walk back towards now — never past it.
      if (Date.parse(candidate.departureAt) <= now.getTime()) continue;
      matches.push(resolved);
    }
    return { currentRevision, matches };
  };

  /** A second opinion never gets to cost the answers the first pass gave. */
  const scanSafe = async (
    requestedAt: string,
    datetimeRepresents: 'departure' | 'arrival' = 'departure'
  ) =>
    scan(requestedAt, datetimeRepresents).catch((error) => {
      if (context.signal?.aborted) throw error;
      return { matches: [] } as SectionCandidates;
    });

  // Asked from just before the selected departure, the planner answers with the
  // best itineraries leaving around then — and it prunes dominated ones, so the
  // *next* service on this very line, arriving later for no fewer transfers, is
  // exactly the kind of answer it drops. This pass still owns the revision of
  // the selected service, since only it can see that service at all.
  const around = await scan(new Date(originalDeparture - 5 * 60_000).toISOString());
  const hasLater = around.matches.some(
    (candidate) => Date.parse(candidate.section.departureAt!) > originalDeparture
  );
  const hasEarlier = around.matches.some(
    (candidate) => Date.parse(candidate.section.departureAt!) < originalDeparture
  );

  const [after, before] = await Promise.all([
    // Ask again from the minute after this departure: with the boarded service
    // out of reach, the one behind it becomes the earliest answer rather than a
    // dominated one.
    hasLater
      ? Promise.resolve(around)
      : scanSafe(new Date(originalDeparture + 60_000).toISOString()),
    // Backwards needs the other search entirely: a departure-anchored plan can
    // only ever look forward. Anchored on an arrival a minute earlier than the
    // one held, the reverse search returns the latest departures that still make
    // it — which is the service just before this one.
    hasEarlier
      ? Promise.resolve(around)
      : scanSafe(new Date(Date.parse(input.journey.arrivalAt) - 60_000).toISOString(), 'arrival'),
  ]);

  const matches = new Map<string, SectionCandidate>();
  for (const candidate of [...around.matches, ...after.matches, ...before.matches]) {
    matches.set(candidate.id, candidate);
  }

  return {
    currentRevision: around.currentRevision,
    matches: [...matches.values()].sort(
      (a, b) => Date.parse(a.section.departureAt!) - Date.parse(b.section.departureAt!)
    ),
  };
}

function hasTimingRevision(current: JourneySection, candidate: JourneySection) {
  return current.departureAt !== candidate.departureAt
    || current.arrivalAt !== candidate.arrivalAt
    || current.scheduledDepartureAt !== candidate.scheduledDepartureAt
    || current.scheduledArrivalAt !== candidate.scheduledArrivalAt;
}

/**
 * Whether a planned ride is another passage of the ride being replaced: the
 * same line, still putting the traveller off where they meant to get off.
 *
 * The headsign is deliberately not part of it. On a RER, consecutive trains
 * towards the same platform carry different mission codes — SARA then ELBA —
 * so comparing them rejected every alternative and left the traveller with the
 * one train the planner happened to pick.
 */
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
  return Boolean(
    originalAlighting?.id
      && candidateAlighting?.id
      && normalize(originalAlighting.id) === normalize(candidateAlighting.id)
  ) || Boolean(
    originalAlighting?.stationId
      && candidateAlighting?.stationId
      && normalize(originalAlighting.stationId) === normalize(candidateAlighting.stationId)
  ) || normalize(original.to.name) === normalize(candidate.to.name)
    || normalize(originalAlighting?.name) === normalize(candidateAlighting?.name)
    // A mission that runs past the stop the traveller wanted still serves them.
    || candidate.stops.some(
      (stop) =>
        normalize(stop.id) === normalize(originalAlighting?.id)
        || (Boolean(stop.stationId)
          && normalize(stop.stationId) === normalize(originalAlighting?.stationId))
    );
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

/** An alternative service, timed and labelled by the feed that produced it. */
function alternativeFor(candidate: SectionCandidate): Alternative {
  const source = sourceOf(candidate.source);
  const timing = departureTiming(candidate.section, source);
  return {
    id: candidate.id,
    departureAt: candidate.section.departureAt!,
    ...timing,
    source,
    candidate,
  };
}

function sourceOf(source: 'idfm-realtime' | 'gtfs-theoretical' | undefined) {
  return source === 'idfm-realtime' ? ('realtime' as const) : ('theoretical' as const);
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

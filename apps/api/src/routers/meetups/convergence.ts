import type {
  Journey,
  JourneySection,
  JourneyStop,
  MeetupJoinPoint,
  MeetupPlan,
  MeetupStation,
} from '@via/contract';

const MAX_EXTRA_DURATION_SECONDS = 15 * 60;
const MAX_EXTRA_TRANSFERS = 1;
const SAME_STOP_TOLERANCE_MS = 3 * 60 * 1_000;

export type ConvergenceParticipantCandidates = {
  participantId: string;
  journeys: Journey[];
};

export type ConvergencePlanInput = {
  participants: ConvergenceParticipantCandidates[];
  destination: MeetupStation;
  targetArrivalAt: Date;
  generatedAt: Date;
  revision: number;
};

type CandidateCombination = {
  journeys: Array<{ participantId: string; journey: Journey }>;
  joinPoints: MeetupJoinPoint[];
  score: readonly [number, number, number, number, string];
};

type Ride = {
  participantId: string;
  section: JourneySection;
  stops: JourneyStop[];
};

/**
 * Selects one bounded journey per Participant and derives only verifiable
 * Jonctions. A route badge or a close timestamp is never evidence of a shared
 * vehicle: the opaque service id and an ordered common stop are both required.
 */
export function buildConvergencePlan(input: ConvergencePlanInput): MeetupPlan {
  const candidates = input.participants.map((participant) => ({
    participantId: participant.participantId,
    journeys: boundedJourneys(participant.journeys),
  }));

  if (candidates.length === 0 || candidates.some((participant) => participant.journeys.length === 0)) {
    return unavailablePlan(input);
  }

  const combinations = cartesian(candidates).map((journeys) => {
    const joinPoints = deriveJoinPoints(journeys, input.destination);
    return {
      journeys,
      joinPoints,
      score: scoreCombination(journeys, joinPoints, input.targetArrivalAt),
    } satisfies CandidateCombination;
  });

  combinations.sort((left, right) => compareScore(left.score, right.score));
  const selected = combinations[0];
  if (!selected) return unavailablePlan(input);

  const latestArrival = Math.max(
    ...selected.journeys.map(({ journey }) => Date.parse(journey.arrivalAt)),
  );
  const latenessSeconds = Math.max(
    0,
    Math.round((latestArrival - input.targetArrivalAt.getTime()) / 1_000),
  );
  const hasJoin = selected.joinPoints.length > 0;

  return {
    revision: input.revision,
    status: hasJoin ? 'ready' : 'fallbackAtDestination',
    generatedAt: input.generatedAt.toISOString(),
    isStale: false,
    ...(!hasJoin
      ? { warning: 'Aucune jonction fiable en route : retrouvez-vous à destination.' }
      : latenessSeconds > 0
        ? { warning: `Le groupe arrivera avec environ ${Math.ceil(latenessSeconds / 60)} min de retard.` }
        : {}),
    participantJourneys: selected.journeys.map(({ participantId, journey }) => ({
      participantId,
      departureAt: journey.departureAt,
      arrivalAt: journey.arrivalAt,
      ...(firstBoardingStation(journey) === undefined
        ? {}
        : { firstBoardingStation: firstBoardingStation(journey) }),
      journey,
    })),
    joinPoints: selected.joinPoints,
  };
}

/**
 * The keep-previous outcome: when a fresh computation is not available (a
 * planner outage, a failed scheduled refresh), the last Plan de convergence is
 * kept, re-stamped with the new revision and marked stale so every surface
 * words the wait identically.
 */
export function stalePlan(previous: MeetupPlan, revision: number): MeetupPlan {
  return {
    ...previous,
    revision,
    isStale: true,
    warning: 'Dernier plan conservé, nouveau calcul en attente.',
  };
}

function boundedJourneys(journeys: Journey[]): Journey[] {
  const ordered = [...journeys]
    .sort((left, right) =>
      left.durationSeconds - right.durationSeconds ||
      left.transferCount - right.transferCount ||
      left.id.localeCompare(right.id),
    )
    .slice(0, 6);
  const baseline = ordered[0];
  if (!baseline) return [];

  return ordered.filter(
    (journey) =>
      journey.durationSeconds <= baseline.durationSeconds + MAX_EXTRA_DURATION_SECONDS &&
      journey.transferCount <= baseline.transferCount + MAX_EXTRA_TRANSFERS,
  );
}

function cartesian(
  participants: Array<{ participantId: string; journeys: Journey[] }>,
): Array<Array<{ participantId: string; journey: Journey }>> {
  let combinations: Array<Array<{ participantId: string; journey: Journey }>> = [[]];
  for (const participant of participants) {
    combinations = combinations.flatMap((combination) =>
      participant.journeys.map((journey) => [
        ...combination,
        { participantId: participant.participantId, journey },
      ]),
    );
  }
  return combinations;
}

function deriveJoinPoints(
  journeys: Array<{ participantId: string; journey: Journey }>,
  destination: MeetupStation,
): MeetupJoinPoint[] {
  const ridesByService = new Map<string, Ride[]>();
  for (const { participantId, journey } of journeys) {
    for (const section of journey.sections) {
      if (section.type !== 'transit' || !section.serviceId) continue;
      const stops = orderedStops(section);
      if (stops.length === 0) continue;
      const rides = ridesByService.get(section.serviceId) ?? [];
      rides.push({ participantId, section, stops });
      ridesByService.set(section.serviceId, rides);
    }
  }

  const possible: MeetupJoinPoint[] = [];
  for (const [serviceId, serviceRides] of ridesByService) {
    const uniqueRides = dedupeRides(serviceRides);
    if (uniqueRides.length < 2) continue;
    for (const subset of rideSubsets(uniqueRides)) {
      const common = earliestCommonStop(subset, destination.id);
      if (!common) continue;

      const participantIds = subset
        .map((ride) => ride.participantId)
        .sort((left, right) => left.localeCompare(right));
      const zones = subset
        .map((ride) => ride.section.boardingPosition?.zone)
        .filter((zone): zone is 'front' | 'middle' | 'rear' => zone !== undefined);
      const zone = zones.length === subset.length && zones.every((value) => value === zones[0])
        ? zones[0] ?? 'middle'
        : 'middle';

      possible.push({
        id: `${serviceId}:${common.station.id}:${participantIds.join(',')}`,
        station: common.station,
        serviceId,
        meetAt: common.at.toISOString(),
        participantIds,
        zone,
      });
    }
  }

  const maximalPossible = possible.filter((point) => !possible.some((candidate) =>
    candidate !== point
      && candidate.serviceId === point.serviceId
      && candidate.station.id === point.station.id
      && Math.abs(Date.parse(candidate.meetAt) - Date.parse(point.meetAt)) <= SAME_STOP_TOLERANCE_MS
      && candidate.participantIds.length > point.participantIds.length
      && point.participantIds.every((id) => candidate.participantIds.includes(id))
  ));

  maximalPossible.sort((left, right) =>
    Date.parse(left.meetAt) - Date.parse(right.meetAt) || left.id.localeCompare(right.id),
  );

  // Keep only events that actually merge two groups. Re-riding another shared
  // service after Alice and Bob already met is useful route data, not a second
  // Jonction.
  const groups = new DisjointParticipantGroups(journeys.map(({ participantId }) => participantId));
  const result: MeetupJoinPoint[] = [];
  for (const point of maximalPossible) {
    const roots = new Set(point.participantIds.map((id) => groups.root(id)));
    if (roots.size < 2) continue;
    groups.merge(point.participantIds);
    result.push(point);
  }
  return result;
}

function rideSubsets(rides: Ride[]): Ride[][] {
  const subsets: Ride[][] = [];
  const count = 1 << rides.length;
  for (let mask = 0; mask < count; mask += 1) {
    const subset = rides.filter((_ride, index) => (mask & (1 << index)) !== 0);
    if (subset.length >= 2) subsets.push(subset);
  }
  return subsets;
}

function dedupeRides(rides: Ride[]): Ride[] {
  const byParticipant = new Map<string, Ride>();
  for (const ride of rides) {
    const existing = byParticipant.get(ride.participantId);
    if (!existing || Date.parse(ride.section.departureAt ?? '') < Date.parse(existing.section.departureAt ?? '')) {
      byParticipant.set(ride.participantId, ride);
    }
  }
  return [...byParticipant.values()];
}

function orderedStops(section: JourneySection): JourneyStop[] {
  return section.stops.filter(
    (stop) => stop.stationId !== undefined && (stop.arrivalAt !== undefined || stop.departureAt !== undefined),
  );
}

function earliestCommonStop(
  rides: Ride[],
  destinationId: string,
): { station: MeetupStation; at: Date } | null {
  const first = rides[0];
  if (!first) return null;

  for (const stop of first.stops) {
    const stationId = stop.stationId;
    if (!stationId || stationId === destinationId) continue;
    const matching = rides.map((ride) => ride.stops.find((candidate) => candidate.stationId === stationId));
    if (matching.some((candidate) => candidate === undefined)) continue;
    const dates = matching.map((candidate) => stopInstant(candidate!));
    if (dates.some((date) => date === null)) continue;
    const timestamps = dates.map((date) => date!.getTime());
    if (Math.max(...timestamps) - Math.min(...timestamps) > SAME_STOP_TOLERANCE_MS) continue;
    if (!hasFollowingCommonStop(rides, stationId)) continue;
    const sample = matching[0]!;
    return {
      station: {
        id: stationId,
        name: sample.name,
        coordinate: sample.coordinate,
      },
      at: new Date(Math.max(...timestamps)),
    };
  }
  return null;
}

function hasFollowingCommonStop(rides: Ride[], stationId: string): boolean {
  const first = rides[0];
  if (!first) return false;
  const firstIndex = first.stops.findIndex((stop) => stop.stationId === stationId);
  if (firstIndex < 0) return false;
  return first.stops.slice(firstIndex + 1).some((following) => {
    if (!following.stationId) return false;
    return rides.slice(1).every((ride) => {
      const joinIndex = ride.stops.findIndex((stop) => stop.stationId === stationId);
      return joinIndex >= 0 && ride.stops.slice(joinIndex + 1)
        .some((stop) => stop.stationId === following.stationId);
    });
  });
}

function stopInstant(stop: JourneyStop): Date | null {
  const raw = stop.departureAt ?? stop.arrivalAt;
  if (!raw) return null;
  const value = new Date(raw);
  return Number.isFinite(value.getTime()) ? value : null;
}

function firstBoardingStation(journey: Journey): MeetupStation | undefined {
  const section = journey.sections.find((candidate) => candidate.type === 'transit');
  const stop = section?.stops.find((candidate) => candidate.stationId !== undefined);
  if (!stop?.stationId) return undefined;
  return { id: stop.stationId, name: stop.name, coordinate: stop.coordinate };
}

function scoreCombination(
  journeys: Array<{ participantId: string; journey: Journey }>,
  joinPoints: MeetupJoinPoint[],
  targetArrivalAt: Date,
): CandidateCombination['score'] {
  const maxLateness = Math.max(
    0,
    ...journeys.map(({ journey }) => Date.parse(journey.arrivalAt) - targetArrivalAt.getTime()),
  );
  const sharedMilliseconds = joinPoints.reduce((total, point) => {
    const latestParticipantArrival = Math.max(
      ...journeys
        .filter(({ participantId }) => point.participantIds.includes(participantId))
        .map(({ journey }) => Date.parse(journey.arrivalAt)),
    );
    return total + Math.max(0, latestParticipantArrival - Date.parse(point.meetAt)) * point.participantIds.length;
  }, 0);
  const totalDuration = journeys.reduce((total, item) => total + item.journey.durationSeconds, 0);
  const walkingDuration = journeys.reduce(
    (total, item) => total + item.journey.walkingDurationSeconds,
    0,
  );
  const tieBreak = journeys.map(({ participantId, journey }) => `${participantId}:${journey.id}`).join('|');
  return [maxLateness, -sharedMilliseconds, totalDuration, walkingDuration, tieBreak];
}

function compareScore(
  left: CandidateCombination['score'],
  right: CandidateCombination['score'],
): number {
  for (let index = 0; index < left.length - 1; index += 1) {
    const comparison = (left[index] as number) - (right[index] as number);
    if (comparison !== 0) return comparison;
  }
  return (left.at(-1) as string).localeCompare(right.at(-1) as string);
}

function unavailablePlan(input: ConvergencePlanInput): MeetupPlan {
  return {
    revision: input.revision,
    status: 'unavailable',
    generatedAt: input.generatedAt.toISOString(),
    isStale: false,
    warning: 'Les itinéraires ne sont pas disponibles pour tous les participants.',
    participantJourneys: [],
    joinPoints: [],
  };
}

class DisjointParticipantGroups {
  private readonly parent = new Map<string, string>();

  constructor(ids: string[]) {
    for (const id of ids) this.parent.set(id, id);
  }

  root(id: string): string {
    const parent = this.parent.get(id) ?? id;
    if (parent === id) return id;
    const root = this.root(parent);
    this.parent.set(id, root);
    return root;
  }

  merge(ids: string[]) {
    const first = ids[0];
    if (!first) return;
    const root = this.root(first);
    for (const id of ids.slice(1)) this.parent.set(this.root(id), root);
  }
}

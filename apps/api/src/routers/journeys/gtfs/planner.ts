import type { Coordinate, Journey, JourneyDestination, JourneySection } from '@via/contract';

import { previousDate, toInstant } from '../../departures/theoretical/service-day';

const WALKING_METERS_PER_SECOND = 1.25;
const MAX_ROUNDS = 2;
const MAX_ACCESS_STOPS = 8;
const MAX_FRONTIER_LABELS = 512;
const ALTERNATIVE_SLACK_SECONDS = 20 * 60;

export type PlannerStop = { id: string; name: string; coordinate: Coordinate };
export type PlannerRoute = {
  id: string;
  shortName: string;
  longName: string;
  mode: 'metro' | 'rer' | 'bus';
  color: string;
  textColor: string;
};
export type PlannerTrip = {
  id: string;
  route: PlannerRoute;
  headsign: string;
  shapeId?: string;
  shape?: Coordinate[];
};
export type PlannerCall = {
  stop: PlannerStop;
  stopSequence: number;
  arrivalSeconds: number;
  departureSeconds: number;
  serviceDate: string;
};
export type PlannerBoarding = {
  tripId: string;
  stopId: string;
  departureSeconds: number;
  serviceDate: string;
};
export type PlannerTransfer = {
  fromStopId: string;
  toStop: PlannerStop;
  minTransferSeconds: number;
};

export type GtfsPlannerLoader = {
  accessStops: (coordinate: Coordinate, limit: number) => Promise<PlannerStop[]>;
  boardings: (
    stopIds: string[],
    earliestByStop: Map<string, number>,
    serviceDates: string[]
  ) => Promise<PlannerBoarding[]>;
  trips: (
    boardings: PlannerBoarding[]
  ) => Promise<Map<string, { trip: PlannerTrip; calls: PlannerCall[] }>>;
  shapes: (shapeIds: string[]) => Promise<Map<string, Coordinate[]>>;
  transfers: (stopIds: string[]) => Promise<PlannerTransfer[]>;
};

type Label = {
  stop: PlannerStop;
  arrivalSeconds: number;
  walkingSeconds: number;
  transfers: number;
  legs: PlannedLeg[];
};

type PlannedLeg =
  | { type: 'walk'; from: PlannerStop | Coordinate; to: PlannerStop | Coordinate; durationSeconds: number }
  | { type: 'wait'; at: PlannerStop; startSeconds: number; durationSeconds: number }
  | { type: 'transfer'; from: PlannerStop; to: PlannerStop; durationSeconds: number }
  | {
      type: 'transit';
      trip: PlannerTrip;
      from: PlannerCall;
      to: PlannerCall;
      calls: PlannerCall[];
    };

const MAX_LABELS_PER_STOP = 4;

type PlannedSection = JourneySection & { shapeId?: string };
type PlannedJourney = Omit<Journey, 'sections'> & { sections: PlannedSection[] };

export async function planWithGtfs(
  origin: Coordinate,
  destination: JourneyDestination,
  now: Date,
  limit: number,
  loader: GtfsPlannerLoader
): Promise<{ status: 'ready' | 'no-route' | 'unavailable'; source: 'gtfs-theoretical'; journeys: Journey[] }> {
  const originStops = (await loader.accessStops(origin, MAX_ACCESS_STOPS)).slice(0, MAX_ACCESS_STOPS);
  const destinationStops = (await loader.accessStops(destination.coordinate, MAX_ACCESS_STOPS)).slice(
    0,
    MAX_ACCESS_STOPS
  );
  if (originStops.length === 0 || destinationStops.length === 0) {
    return { status: 'unavailable', source: 'gtfs-theoretical', journeys: [] };
  }

  const destinationIds = new Set(destinationStops.map((stop) => stop.id));
  const { date, seconds } = parisServiceDay(now);
  const serviceDates = [date, previousDate(date)];
  const initial = new Map<string, Label[]>();
  for (const stop of originStops) {
    const walkingSeconds = walkingDuration(origin, stop.coordinate);
    addParetoLabel(initial, {
      stop,
      arrivalSeconds: seconds + walkingSeconds,
      walkingSeconds,
      transfers: 0,
      legs: [{ type: 'walk', from: origin, to: stop, durationSeconds: walkingSeconds }],
    });
  }

  let frontier = [...initial.values()].flat();
  const results: PlannedJourney[] = [];
  let bestArrivalSeconds = Infinity;

  for (let round = 0; round <= MAX_ROUNDS && frontier.length > 0; round += 1) {
    const earliestByStop = new Map<string, number>();
    for (const label of frontier) {
      earliestByStop.set(
        label.stop.id,
        Math.min(earliestByStop.get(label.stop.id) ?? Infinity, label.arrivalSeconds)
      );
    }
    const boardings = await loader.boardings([...earliestByStop.keys()], earliestByStop, serviceDates);
    const trips = await loader.trips(boardings);
    const next = new Map<string, Label[]>();
    const seenBoardings = new Set<string>();

    for (const boarding of boardings) {
      const boardingKey = `${plannerTripKey(boarding.tripId, boarding.serviceDate)}:${boarding.stopId}:${boarding.departureSeconds}`;
      if (seenBoardings.has(boardingKey)) continue;
      seenBoardings.add(boardingKey);
      const bases = frontier.filter(
        (label) =>
          label.stop.id === boarding.stopId && label.arrivalSeconds <= boarding.departureSeconds
      );
      if (bases.length === 0) continue;

      const loaded = trips.get(plannerTripKey(boarding.tripId, boarding.serviceDate));
      if (!loaded) continue;
      const fromIndex = loaded.calls.findIndex(
        (call) => call.stop.id === boarding.stopId && call.departureSeconds === boarding.departureSeconds
      );
      if (fromIndex < 0) continue;
      const from = loaded.calls[fromIndex];

      for (const base of bases) {
        if (usedRouteIds(base).has(loaded.trip.route.id)) continue;
        const visitedStops = visitedStopIds(base);
        const waitSeconds = Math.max(0, from.departureSeconds - base.arrivalSeconds);
        for (let toIndex = fromIndex + 1; toIndex < loaded.calls.length; toIndex += 1) {
          const to = loaded.calls[toIndex]!;
          if (visitedStops.has(to.stop.id)) continue;
          if (to.arrivalSeconds < base.arrivalSeconds) continue;
          const label: Label = {
            stop: to.stop,
            arrivalSeconds: to.arrivalSeconds,
            walkingSeconds: base.walkingSeconds,
            transfers: base.transfers,
            legs: [
              ...base.legs,
              ...(waitSeconds > 0
                ? [
                    {
                      type: 'wait' as const,
                      at: base.stop,
                      startSeconds: base.arrivalSeconds,
                      durationSeconds: waitSeconds,
                    },
                  ]
                : []),
              {
                type: 'transit',
                trip: loaded.trip,
                from,
                to,
                calls: loaded.calls.slice(fromIndex, toIndex + 1),
              },
            ],
          };
          addParetoLabel(next, label);
          if (destinationIds.has(to.stop.id)) {
            results.push(toJourney(origin, destination, label, to, date, seconds));
            bestArrivalSeconds = Math.min(
              bestArrivalSeconds,
              label.arrivalSeconds + walkingDuration(to.stop.coordinate, destination.coordinate)
            );
          }
        }
      }
    }

    const transferRows = await loader.transfers([...next.keys()]);
    const expanded = new Map([...next].map(([stopId, labels]) => [stopId, [...labels]]));
    for (const transfer of transferRows) {
      for (const base of next.get(transfer.fromStopId) ?? []) {
        addParetoLabel(expanded, {
          stop: transfer.toStop,
          arrivalSeconds: base.arrivalSeconds + transfer.minTransferSeconds,
          walkingSeconds: base.walkingSeconds + transfer.minTransferSeconds,
          transfers: base.transfers + 1,
          legs: [
            ...base.legs,
            {
              type: 'transfer',
              from: base.stop,
              to: transfer.toStop,
              durationSeconds: transfer.minTransferSeconds,
            },
          ],
        });
      }
    }
    frontier = [...expanded.values()]
      .flat()
      .filter((label) => label.arrivalSeconds <= bestArrivalSeconds + ALTERNATIVE_SLACK_SECONDS)
      .sort(
        (a, b) =>
          a.arrivalSeconds - b.arrivalSeconds ||
          a.walkingSeconds - b.walkingSeconds ||
          a.transfers - b.transfers
      )
      .slice(0, MAX_FRONTIER_LABELS);
  }

  const selected = dedupeAndQualify(results, limit);
  const shapeIds = [
    ...new Set(
      selected.flatMap((journey) => journey.sections.flatMap((section) => section.shapeId ?? []))
    ),
  ];
  const shapes = await loader.shapes(shapeIds);
  const journeys: Journey[] = selected.map(({ sections, ...journey }) => ({
    ...journey,
    sections: sections.map(({ shapeId, ...section }) => ({
      ...section,
      geometry:
        shapeId && section.type === 'transit'
          ? sliceShape(
              shapes.get(shapeId) ?? section.geometry,
              section.from.coordinate,
              section.to.coordinate
            )
          : section.geometry,
    })),
  }));
  return {
    status: journeys.length > 0 ? 'ready' : 'no-route',
    source: 'gtfs-theoretical',
    journeys,
  };
}

function toJourney(
  origin: Coordinate,
  destination: JourneyDestination,
  label: Label,
  finalCall: PlannerCall,
  serviceDate: string,
  departureSeconds: number
): PlannedJourney {
  const lastStop = finalCall.stop;
  const egressSeconds = walkingDuration(lastStop.coordinate, destination.coordinate);
  const legs: PlannedLeg[] = [
    ...label.legs,
    { type: 'walk', from: lastStop, to: destination.coordinate, durationSeconds: egressSeconds },
  ];
  const arrivalSeconds = label.arrivalSeconds + egressSeconds;
  const sections = legs.map((leg) => toSection(leg, serviceDate));
  const transitSignature = sections
    .flatMap((section) => (section.type === 'transit' ? [section.route?.id ?? 'unknown'] : []))
    .join(',');
  const transitCount = sections.filter((section) => section.type === 'transit').length;

  return {
    id: `${destination.id}:${departureSeconds}:${arrivalSeconds}:${transitSignature}`,
    qualifier: 'recommended',
    durationSeconds: Math.max(0, arrivalSeconds - departureSeconds),
    walkingDurationSeconds: label.walkingSeconds + egressSeconds,
    transferCount: Math.max(0, transitCount - 1),
    departureAt: toInstant(serviceDate, departureSeconds),
    arrivalAt: toInstant(serviceDate, arrivalSeconds),
    status: 'theoretical',
    warnings: ['Horaires théoriques issus du GTFS'],
    sections,
  };
}

function toSection(leg: PlannedLeg, serviceDate: string) {
  if (leg.type === 'walk') {
    const from = coordinateOf(leg.from);
    const to = coordinateOf(leg.to);
    return {
      type: 'walk' as const,
      durationSeconds: leg.durationSeconds,
      from: { name: nameOf(leg.from), coordinate: from },
      to: { name: nameOf(leg.to), coordinate: to },
      geometry: [from, to],
      stops: [],
    };
  }
  if (leg.type === 'wait') {
    return {
      type: 'wait' as const,
      durationSeconds: leg.durationSeconds,
      from: { name: leg.at.name, coordinate: leg.at.coordinate },
      to: { name: leg.at.name, coordinate: leg.at.coordinate },
      departureAt: toInstant(serviceDate, leg.startSeconds),
      arrivalAt: toInstant(serviceDate, leg.startSeconds + leg.durationSeconds),
      geometry: [leg.at.coordinate],
      stops: [],
    };
  }
  if (leg.type === 'transfer') {
    return {
      type: 'transfer' as const,
      durationSeconds: leg.durationSeconds,
      from: { name: leg.from.name, coordinate: leg.from.coordinate },
      to: { name: leg.to.name, coordinate: leg.to.coordinate },
      geometry: [leg.from.coordinate, leg.to.coordinate],
      stops: [],
    };
  }

  const geometry = leg.trip.shape?.length
    ? sliceShape(leg.trip.shape, leg.from.stop.coordinate, leg.to.stop.coordinate)
    : [leg.from.stop.coordinate, leg.to.stop.coordinate];
  return {
    type: 'transit' as const,
    durationSeconds: Math.max(0, leg.to.arrivalSeconds - leg.from.departureSeconds),
    from: { name: leg.from.stop.name, coordinate: leg.from.stop.coordinate },
    to: { name: leg.to.stop.name, coordinate: leg.to.stop.coordinate },
    departureAt: toInstant(serviceDate, leg.from.departureSeconds),
    arrivalAt: toInstant(serviceDate, leg.to.arrivalSeconds),
    geometry,
    shapeId: leg.trip.shapeId,
    route: leg.trip.route,
    direction: leg.trip.headsign,
    stops: leg.calls.map((call) => ({
      id: call.stop.id,
      name: call.stop.name,
      coordinate: call.stop.coordinate,
      arrivalAt: toInstant(serviceDate, call.arrivalSeconds),
      departureAt: toInstant(serviceDate, call.departureSeconds),
    })),
  };
}

function dedupeAndQualify(journeys: PlannedJourney[], limit: number) {
  const deduped = [...new Map(journeys.map((journey) => [journey.id, journey])).values()];
  const pareto = deduped.filter(
    (journey) => !deduped.some((other) => other !== journey && dominatesJourney(other, journey))
  );
  const sorted = pareto
    .sort((a, b) => a.arrivalAt.localeCompare(b.arrivalAt) || a.walkingDurationSeconds - b.walkingDurationSeconds)
    .slice(0, Math.max(limit * 2, limit));
  const fastest = sorted.reduce((best, journey) => (journey.durationSeconds < best.durationSeconds ? journey : best), sorted[0]);
  const leastWalking = sorted.reduce(
    (best, journey) => (journey.walkingDurationSeconds < best.walkingDurationSeconds ? journey : best),
    sorted[0]
  );
  return sorted.slice(0, limit).map((journey, index) => ({
    ...journey,
    qualifier: (index === 0
      ? 'recommended'
      : journey.id === fastest?.id
        ? 'rapid'
        : journey.id === leastWalking?.id
          ? 'less-walking'
          : journey.sections.every((section) => section.type === 'walk')
            ? 'walking'
            : 'comfort') as Journey['qualifier'],
  }));
}

function dominatesJourney(a: PlannedJourney, b: PlannedJourney) {
  const arrivalNoLater = a.arrivalAt <= b.arrivalAt;
  const walkingNoLonger = a.walkingDurationSeconds <= b.walkingDurationSeconds;
  const transfersNoMore = a.transferCount <= b.transferCount;
  return (
    arrivalNoLater &&
    walkingNoLonger &&
    transfersNoMore &&
    (a.arrivalAt < b.arrivalAt ||
      a.walkingDurationSeconds < b.walkingDurationSeconds ||
      a.transferCount < b.transferCount)
  );
}

function usedRouteIds(label: Label) {
  return new Set(
    label.legs.flatMap((leg) => (leg.type === 'transit' ? [leg.trip.route.id] : []))
  );
}

function visitedStopIds(label: Label) {
  const ids = new Set<string>();
  for (const leg of label.legs) {
    if (leg.type === 'transit') {
      for (const call of leg.calls) ids.add(call.stop.id);
    } else if (leg.type === 'transfer') {
      ids.add(leg.from.id);
      ids.add(leg.to.id);
    } else if (leg.type === 'wait') {
      ids.add(leg.at.id);
    } else {
      if ('id' in leg.from) ids.add(leg.from.id);
      if ('id' in leg.to) ids.add(leg.to.id);
    }
  }
  return ids;
}

function addParetoLabel(labelsByStop: Map<string, Label[]>, next: Label) {
  const current = labelsByStop.get(next.stop.id) ?? [];
  if (current.some((label) => dominates(label, next))) return;
  const kept = current.filter((label) => !dominates(next, label));
  kept.push(next);
  kept.sort(
    (a, b) =>
      a.arrivalSeconds - b.arrivalSeconds ||
      a.walkingSeconds - b.walkingSeconds ||
      a.transfers - b.transfers
  );
  labelsByStop.set(next.stop.id, kept.slice(0, MAX_LABELS_PER_STOP));
}

function dominates(a: Label, b: Label) {
  return (
    a.arrivalSeconds <= b.arrivalSeconds &&
    a.walkingSeconds <= b.walkingSeconds &&
    a.transfers <= b.transfers &&
    (a.arrivalSeconds < b.arrivalSeconds ||
      a.walkingSeconds < b.walkingSeconds ||
      a.transfers < b.transfers)
  );
}

export function plannerTripKey(tripId: string, serviceDate: string) {
  return `${tripId}:${serviceDate}`;
}

function sliceShape(shape: Coordinate[], from: Coordinate, to: Coordinate) {
  const fromIndex = closestCoordinateIndex(shape, from);
  const toIndex = closestCoordinateIndex(shape, to);
  const segment =
    fromIndex <= toIndex
      ? shape.slice(fromIndex, toIndex + 1)
      : shape.slice(toIndex, fromIndex + 1).reverse();
  return [from, ...segment, to];
}

function closestCoordinateIndex(shape: Coordinate[], target: Coordinate) {
  let bestIndex = 0;
  let bestDistance = Infinity;
  for (let index = 0; index < shape.length; index += 1) {
    const point = shape[index]!;
    const distance =
      (point.latitude - target.latitude) ** 2 +
      (point.longitude - target.longitude) ** 2;
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = index;
    }
  }
  return bestIndex;
}

function walkingDuration(from: Coordinate, to: Coordinate) {
  return Math.max(60, Math.ceil(haversineMeters(from, to) / WALKING_METERS_PER_SECOND));
}

function haversineMeters(a: Coordinate, b: Coordinate) {
  const radius = 6_371_000;
  const latitudeA = (a.latitude * Math.PI) / 180;
  const latitudeB = (b.latitude * Math.PI) / 180;
  const dLatitude = ((b.latitude - a.latitude) * Math.PI) / 180;
  const dLongitude = ((b.longitude - a.longitude) * Math.PI) / 180;
  const value =
    Math.sin(dLatitude / 2) ** 2 +
    Math.cos(latitudeA) * Math.cos(latitudeB) * Math.sin(dLongitude / 2) ** 2;
  return 2 * radius * Math.asin(Math.sqrt(value));
}

function coordinateOf(value: PlannerStop | Coordinate): Coordinate {
  return 'coordinate' in value ? value.coordinate : value;
}

function nameOf(value: PlannerStop | Coordinate) {
  return 'name' in value ? value.name : 'Départ';
}

function parisServiceDay(now: Date) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Paris',
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
  const parts = Object.fromEntries(formatter.formatToParts(now).map(({ type, value }) => [type, value]));
  const hour = parts.hour === '24' ? '00' : parts.hour;
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    seconds: Number(hour) * 3600 + Number(parts.minute) * 60 + Number(parts.second),
  };
}

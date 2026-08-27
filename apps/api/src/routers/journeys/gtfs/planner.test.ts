import { expect, test } from 'bun:test';
import type { Coordinate, JourneyDestination } from '@via/contract';

import type { GtfsPlannerLoader, PlannerCall, PlannerStop, PlannerTrip } from './planner';
import { plannerTripKey, planWithGtfs } from './planner';

const origin: Coordinate = { latitude: 48.8566, longitude: 2.3522 };
const destination: JourneyDestination = {
  kind: 'address',
  id: 'rivoli',
  name: '12 rue de Rivoli',
  coordinate: { latitude: 48.8556, longitude: 2.35995 },
};
const now = new Date('2026-08-12T10:00:00Z');
const date = '2026-08-12';
const from: PlannerStop = { id: 'from', name: 'République', coordinate: { latitude: 48.8567, longitude: 2.3523 } };
const to: PlannerStop = { id: 'to', name: 'Hôtel de Ville', coordinate: { latitude: 48.8557, longitude: 2.3598 } };
const route = { id: 'metro-1', shortName: '1', longName: 'Métro 1', mode: 'metro' as const, color: '#FFCD00', textColor: '#000000' };
const trip: PlannerTrip = { id: 'trip-1', route, headsign: 'Château de Vincennes' };

function loaderFor(calls: PlannerCall[]): GtfsPlannerLoader {
  return {
    accessStops: async (_coordinate, limit) => [from, to].slice(0, limit),
    boardings: async (stopIds, earliestByStop) =>
      stopIds.includes(from.id) && (earliestByStop.get(from.id) ?? Infinity) <= 45_000
        ? [{ tripId: trip.id, stopId: from.id, departureSeconds: 45_000, serviceDate: date }]
        : [],
    alightings: async (stopIds, latestByStop) =>
      stopIds.includes(to.id) && (latestByStop.get(to.id) ?? -Infinity) >= 45_600
        ? [{ tripId: trip.id, stopId: to.id, arrivalSeconds: 45_600, serviceDate: date }]
        : [],
    trips: async (boardings) =>
      new Map(
        boardings.map((boarding) => [
          plannerTripKey(boarding.tripId, boarding.serviceDate),
          { trip, calls },
        ])
      ),
    shapes: async () => new Map(),
    transfers: async () => [],
    reverseTransfers: async () => [],
  };
}

test('builds a direct journey with walking access and egress', async () => {
  const calls: PlannerCall[] = [
    { stop: from, stopSequence: 1, arrivalSeconds: 45_000, departureSeconds: 45_000, serviceDate: date },
    { stop: to, stopSequence: 2, arrivalSeconds: 45_600, departureSeconds: 45_600, serviceDate: date },
  ];
  const response = await planWithGtfs(origin, destination, now, 4, loaderFor(calls));

  expect(response.status).toBe('ready');
  expect(response.journeys).toHaveLength(1);
  expect(response.journeys[0]?.status).toBe('theoretical');
  expect(response.journeys[0]?.warnings).toEqual([]);
  expect(response.journeys[0]?.sections.map((section) => section.type)).toEqual([
    'walk',
    'wait',
    'transit',
    'walk',
  ]);
});

test('finds the latest exact departure for an arrival deadline', async () => {
  const calls: PlannerCall[] = [
    { stop: from, stopSequence: 1, arrivalSeconds: 45_000, departureSeconds: 45_000, serviceDate: date },
    { stop: to, stopSequence: 2, arrivalSeconds: 45_600, departureSeconds: 45_600, serviceDate: date },
  ];
  const deadline = new Date('2026-08-12T11:45:00Z');
  const response = await planWithGtfs(
    origin,
    destination,
    deadline,
    4,
    loaderFor(calls),
    'arrival'
  );

  expect(response.status).toBe('ready');
  expect(response.journeys[0]?.arrivalAt <= deadline.toISOString()).toBe(true);
  expect(response.journeys[0]?.sections.map((section) => section.type)).toEqual([
    'walk',
    'transit',
    'wait',
    'walk',
  ]);
});

test('returns no-route when no departure can board from the access stops', async () => {
  const response = await planWithGtfs(origin, destination, now, 4, {
    ...loaderFor([]),
    boardings: async () => [],
  });
  expect(response.status).toBe('no-route');
  expect(response.journeys).toEqual([]);
});

test('does not query a frontier stop that cannot reach the target in the alternative window', async () => {
  const far = {
    id: 'far',
    name: 'Arrêt lointain',
    coordinate: { latitude: 51.5, longitude: 2.35 },
  } satisfies PlannerStop;
  const calls: PlannerCall[] = [
    { stop: from, stopSequence: 1, arrivalSeconds: 45_000, departureSeconds: 45_000, serviceDate: date },
    { stop: to, stopSequence: 2, arrivalSeconds: 45_600, departureSeconds: 45_600, serviceDate: date },
    { stop: far, stopSequence: 3, arrivalSeconds: 45_700, departureSeconds: 45_700, serviceDate: date },
  ];
  const requestedStops: string[][] = [];
  const response = await planWithGtfs(origin, destination, now, 4, {
    ...loaderFor(calls),
    accessStops: async (coordinate) =>
      coordinate === origin ? [from] : [to],
    boardings: async (stopIds, earliestByStop) => {
      requestedStops.push(stopIds);
      return stopIds.includes(from.id) && (earliestByStop.get(from.id) ?? Infinity) <= 45_000
        ? [{ tripId: trip.id, stopId: from.id, departureSeconds: 45_000, serviceDate: date }]
        : []
    },
  });
  expect(response.status).toBe('ready');
  expect(requestedStops[0]).toEqual([from.id]);
  expect(requestedStops.slice(1).flat()).not.toContain(far.id);
});

test('does not query a reverse frontier stop that cannot reach the origin in the alternative window', async () => {
  const far = {
    id: 'far',
    name: 'Arrêt lointain',
    coordinate: { latitude: 51.5, longitude: 2.35 },
  } satisfies PlannerStop;
  const calls: PlannerCall[] = [
    { stop: far, stopSequence: 1, arrivalSeconds: 44_000, departureSeconds: 44_000, serviceDate: date },
    { stop: from, stopSequence: 2, arrivalSeconds: 45_000, departureSeconds: 45_000, serviceDate: date },
    { stop: to, stopSequence: 3, arrivalSeconds: 45_600, departureSeconds: 45_600, serviceDate: date },
  ];
  const requestedStops: string[][] = [];
  const response = await planWithGtfs(
    origin,
    destination,
    new Date('2026-08-12T11:45:00Z'),
    4,
    {
      ...loaderFor(calls),
      accessStops: async (coordinate) =>
        coordinate === origin ? [from] : [to],
      alightings: async (stopIds, latestByStop) => {
        requestedStops.push(stopIds);
        return stopIds.includes(to.id) && (latestByStop.get(to.id) ?? -Infinity) >= 45_600
          ? [{ tripId: trip.id, stopId: to.id, arrivalSeconds: 45_600, serviceDate: date }]
          : [];
      },
    },
    'arrival'
  );

  expect(response.status).toBe('ready');
  expect(requestedStops[0]).toEqual([to.id]);
  expect(requestedStops.slice(1).flat()).not.toContain(far.id);
});

/**
 * A suburban origin, a dense first leg, and one connecting station reached at
 * the very end of it: the shape that used to come back with nothing to ride.
 * The frontier ceiling is a label count, and Pareto keeps up to four labels per
 * stop, so the local stops the bus threads through can fill it entirely and cut
 * the station the whole journey depends on.
 */
test('keeps the connecting station a long first leg reaches, however dense that leg is', async () => {
  const localStops: PlannerStop[] = Array.from({ length: 130 }, (_, index) => ({
    id: `local-${index}`,
    name: `Arrêt ${index}`,
    coordinate: { latitude: 48.94 + index * 0.0001, longitude: 2.03 },
  }));
  const link: PlannerStop = {
    id: 'link',
    name: 'Poissy',
    coordinate: { latitude: 48.929, longitude: 2.042 },
  };
  const exit: PlannerStop = {
    id: 'exit',
    name: 'Auber',
    coordinate: { latitude: 48.8725, longitude: 2.3295 },
  };
  const suburb: Coordinate = { latitude: 48.9376, longitude: 2.0334 };
  const paris: JourneyDestination = {
    kind: 'address',
    id: 'vivienne',
    name: '15 rue Vivienne',
    coordinate: { latitude: 48.8695, longitude: 2.3405 },
  };
  // Four access stops at four walking distances: the same local stop then holds
  // four labels no other dominates, which is what fills the frontier.
  const accessStops: PlannerStop[] = Array.from({ length: 4 }, (_, index) => ({
    id: `access-${index}`,
    name: `Départ ${index}`,
    coordinate: { latitude: 48.9376, longitude: 2.0334 + index * 0.002 },
  }));
  const busRoute = { id: 'bus-2', shortName: '2', longName: 'Bus 2', mode: 'bus' as const, color: '#666666', textColor: '#FFFFFF' };
  const rerRoute = { id: 'rer-a', shortName: 'A', longName: 'RER A', mode: 'rer' as const, color: '#E3051C', textColor: '#FFFFFF' };
  // The furthest access stop leaves first, so its labels arrive earlier while
  // costing more walking — neither label dominates the other.
  const busTrips = accessStops.map((stop, index) => {
    const departureSeconds = 44_000 + (accessStops.length - 1 - index) * 100;
    const calls: PlannerCall[] = [
      { stop, stopSequence: 0, arrivalSeconds: departureSeconds, departureSeconds, serviceDate: date },
      ...localStops.map((localStop, position) => ({
        stop: localStop,
        stopSequence: position + 1,
        arrivalSeconds: departureSeconds + (position + 1) * 10,
        departureSeconds: departureSeconds + (position + 1) * 10,
        serviceDate: date,
      })),
    ];
    // Only the nearest access stop's bus carries on to the station, and it gets
    // there last: the plain cut down the ranking dropped exactly that label.
    if (index === 0) {
      calls.push({ stop: link, stopSequence: calls.length, arrivalSeconds: 45_700, departureSeconds: 45_700, serviceDate: date });
    }
    return {
      trip: { id: `bus-trip-${index}`, route: busRoute, headsign: 'Poissy' },
      calls,
      boarding: { tripId: `bus-trip-${index}`, stopId: stop.id, departureSeconds, serviceDate: date },
    };
  });
  const rerCalls: PlannerCall[] = [
    { stop: link, stopSequence: 0, arrivalSeconds: 46_000, departureSeconds: 46_000, serviceDate: date },
    { stop: exit, stopSequence: 1, arrivalSeconds: 47_800, departureSeconds: 47_800, serviceDate: date },
  ];
  const rerTrip: PlannerTrip = { id: 'rer-trip', route: rerRoute, headsign: 'Boissy' };
  const tripsById = new Map<string, { trip: PlannerTrip; calls: PlannerCall[] }>([
    ...busTrips.map((bus) => [bus.trip.id, { trip: bus.trip, calls: bus.calls }] as const),
    [rerTrip.id, { trip: rerTrip, calls: rerCalls }],
  ]);

  const response = await planWithGtfs(suburb, paris, new Date('2026-08-12T10:00:00Z'), 4, {
    accessStops: async (coordinate) => (coordinate === suburb ? accessStops : [exit]),
    boardings: async (stopIds) => [
      ...busTrips
        .filter((bus) => stopIds.includes(bus.boarding.stopId))
        .map((bus) => bus.boarding),
      ...(stopIds.includes(link.id)
        ? [{ tripId: rerTrip.id, stopId: link.id, departureSeconds: 46_000, serviceDate: date }]
        : []),
    ],
    alightings: async () => [],
    trips: async (references) =>
      new Map(
        references.flatMap((reference) => {
          const loaded = tripsById.get(reference.tripId);
          return loaded
            ? [[plannerTripKey(reference.tripId, reference.serviceDate), loaded] as const]
            : [];
        })
      ),
    shapes: async () => new Map(),
    transfers: async () => [],
    reverseTransfers: async () => [],
  });

  expect(response.status).toBe('ready');
  expect(
    response.journeys[0]?.sections.flatMap((section) =>
      section.type === 'transit' && section.route ? [section.route.shortName] : []
    )
  ).toEqual(['2', 'A']);
});

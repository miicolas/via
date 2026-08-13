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
    trips: async (boardings) =>
      new Map(
        boardings.map((boarding) => [
          plannerTripKey(boarding.tripId, boarding.serviceDate),
          { trip, calls },
        ])
      ),
    shapes: async () => new Map(),
    transfers: async () => [],
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
  expect(response.journeys[0]?.sections.map((section) => section.type)).toEqual([
    'walk',
    'wait',
    'transit',
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

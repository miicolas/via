import { describe, expect, test } from 'bun:test';
import type { Journey, JourneyDepartureChoicesInput, JourneySection } from '@via/contract';

import type { CachedStationSnapshot } from '../departures/cache';
import { createJourneyDepartureChoicesModule } from './departure-choices';
import type { JourneyPlanner } from './service';
import type { TimetableRun, TimetableRunReader } from './timetable-runs';

const now = new Date('2026-08-22T09:59:00Z');
const destination = {
  kind: 'station' as const,
  id: 'destination',
  name: 'Destination',
  coordinate: { latitude: 48.9, longitude: 2.4 },
};

const scheduledRuns: TimetableRunReader = async () => [
  run('trip-gone', '09:52'),
  run('trip-1', '10:05'),
  run('trip-2', '10:12'),
  run('trip-3', '10:19'),
  run('trip-4', '10:26'),
];

describe('journey departure choices module', () => {
  test('builds a passive refresh from GTFS and leaves the journey untouched', async () => {
    const current = journey();
    const { module, calls } = setup({ timetable: scheduledRuns });

    const response = await module.resolve(input(current), { identity: 'person' });

    expect(response.journey).toEqual(current);
    expect(response.groups[0]).toMatchObject({
      sectionId: 'ride',
      availability: 'ready',
      choices: [
        { scheduledAt: '2026-08-22T10:00:00Z', isSelected: true },
        { scheduledAt: '2026-08-22T10:05:00.000Z', isSelected: false },
        { scheduledAt: '2026-08-22T10:12:00.000Z', isSelected: false },
        { scheduledAt: '2026-08-22T10:19:00.000Z', isSelected: false },
      ],
    });
    expect(calls).toHaveLength(0);
  });

  test('a missing Redis snapshot keeps GTFS choices theoretical', async () => {
    const { module, calls } = setup({
      timetable: scheduledRuns,
      snapshot: async () => null,
    });

    const response = await module.resolve(input(journey()), { identity: 'person' });

    expect(response.groups[0]?.choices.slice(1).every(
      (choice) => choice.source === 'theoretical' && choice.status === 'scheduled',
    )).toBe(true);
    expect(response.groups[0]?.fetchedAt).toBeUndefined();
    expect(calls).toHaveLength(0);
  });

  test('enriches GTFS passages by canonical trip id then by destination and time', async () => {
    const snapshot = stationSnapshot([
      {
        routeId: 'line-a',
        destination: 'A destination deliberately ignored by the exact match',
        scheduledAt: epoch('10:05'),
        expectedAt: epoch('10:08'),
        providerJourneyRef: 'vehicle_journey:trip-1',
      },
      {
        routeId: 'line-a',
        destination: 'Déstination',
        scheduledAt: epoch('10:12'),
        expectedAt: epoch('10:13'),
      },
    ]);
    const { module, calls } = setup({
      timetable: scheduledRuns,
      snapshot: async () => snapshot,
    });

    const response = await module.resolve(input(journey()), { identity: 'person' });
    const choices = response.groups[0]!.choices;

    expect(choices.find((choice) => choice.id === 'departure:ride:trip-1')).toMatchObject({
      id: 'departure:ride:trip-1',
      scheduledAt: '2026-08-22T10:05:00.000Z',
      expectedAt: '2026-08-22T10:08:00.000Z',
      status: 'delayed',
      source: 'realtime',
    });
    expect(choices.find((choice) => choice.id === 'departure:ride:trip-2')).toMatchObject({
      expectedAt: '2026-08-22T10:13:00.000Z',
      status: 'on_time',
      source: 'realtime',
    });
    expect(response.groups[0]?.fetchedAt).toBe('2026-08-22T09:58:00.000Z');
    expect(calls).toHaveLength(0);
  });

  test('one realtime visit enriches only the closest GTFS passage', async () => {
    const timetable: TimetableRunReader = async () => [
      run('trip-1', '10:05'),
      run('trip-2', '10:07'),
    ];
    const snapshot = stationSnapshot([{
      routeId: 'line-a',
      destination: 'Destination',
      expectedAt: epoch('10:07'),
    }]);
    const { module } = setup({ timetable, snapshot: async () => snapshot });

    const response = await module.resolve(input(journey()), { identity: 'person' });
    const alternatives = response.groups[0]!.choices.filter((choice) => !choice.isSelected);

    expect(alternatives).toMatchObject([
      { id: 'departure:ride:trip-1', source: 'theoretical' },
      { id: 'departure:ride:trip-2', source: 'realtime' },
    ]);
  });

  test('a partial timetable failure returns the unchanged journey and no planner call', async () => {
    const current = journey();
    const { module, calls } = setup({
      timetable: async () => {
        throw new Error('database unavailable');
      },
      snapshot: async () => {
        throw new Error('redis unavailable');
      },
    });

    const response = await module.resolve(input(current), { identity: 'person' });

    expect(response.journey).toEqual(current);
    expect(response.groups[0]).toMatchObject({
      availability: 'unavailable',
      choices: [{ isSelected: true }],
    });
    expect(calls).toHaveLength(0);
  });

  test('selecting a passage that keeps the downstream connection costs no plan', async () => {
    const current = connectingJourney();
    const snapshot = stationSnapshot([{
      routeId: 'line-a',
      destination: 'Destination',
      scheduledAt: epoch('10:05'),
      expectedAt: epoch('10:08'),
      providerJourneyRef: 'trip:trip-1',
    }]);
    const { module, calls } = setup({
      timetable: async (query) => query.routeId === 'line-a' ? [run('trip-1', '10:05')] : [],
      snapshot: async () => snapshot,
    });

    const response = await module.resolve(
      input(current, { sectionId: 'ride', departureId: 'departure:ride:trip-1' }),
      { identity: 'person' },
    );

    expect(calls).toHaveLength(0);
    expect(response.journey.sections.find((section) => section.id === 'ride')).toMatchObject({
      serviceId: 'trip-1',
      departureAt: '2026-08-22T10:08:00.000Z',
      arrivalAt: '2026-08-22T10:38:00.000Z',
      scheduledDepartureAt: '2026-08-22T10:05:00.000Z',
      scheduledArrivalAt: '2026-08-22T10:35:00.000Z',
      timingSource: 'realtime',
      departureStatus: 'delayed',
    });
    expect(response.journey.sections.find((section) => section.id === 'connection')).toMatchObject({
      departureAt: '2026-08-22T10:40:00Z',
    });
  });

  test('a broken downstream connection performs one plan from the alighting station', async () => {
    const downstream = journey('downstream', '2026-08-22T10:50:00Z', '2026-08-22T11:10:00Z');
    downstream.departureAt = '2026-08-22T10:45:00Z';
    downstream.sections[0] = {
      ...downstream.sections[0]!,
      departureAt: '2026-08-22T10:45:00Z',
      arrivalAt: '2026-08-22T10:50:00Z',
    };
    const { module, calls } = setup({
      timetable: async (query) => query.routeId === 'line-a' ? [run('trip-late', '10:12')] : [],
      plan: async () => plannerResponse([downstream]),
    });

    const response = await module.resolve(
      input(connectingJourney(), {
        sectionId: 'ride',
        departureId: 'departure:ride:trip-late',
      }),
      { identity: 'person' },
    );

    expect(calls).toHaveLength(1);
    expect(calls[0]).toMatchObject({
      originStationId: 'station-b',
      requestedAt: '2026-08-22T10:42:00.000Z',
    });
    expect(response.journey.sections.find((section) => section.id === 'ride')).toMatchObject({
      serviceId: 'trip-late',
      departureAt: '2026-08-22T10:12:00.000Z',
      arrivalAt: '2026-08-22T10:42:00.000Z',
    });
    expect(response.journey.arrivalAt).toBe('2026-08-22T11:10:00Z');
  });

  test('a failed downstream replan returns the existing unavailable error without mutation', async () => {
    const current = connectingJourney();
    const before = structuredClone(current);
    const { module, calls } = setup({
      timetable: async (query) => query.routeId === 'line-a' ? [run('trip-late', '10:12')] : [],
      plan: async () => {
        throw new Error('provider unavailable');
      },
    });

    await expect(module.resolve(
      input(current, { sectionId: 'ride', departureId: 'departure:ride:trip-late' }),
      { identity: 'person' },
    )).rejects.toThrow('no longer available');

    expect(calls).toHaveLength(1);
    expect(current).toEqual(before);
  });

  test('rejects a stale selection without calling the planner', async () => {
    const { module, calls } = setup({ timetable: scheduledRuns });

    await expect(module.resolve(
      input(journey(), { sectionId: 'ride', departureId: 'departure:ride:gone' }),
      { identity: 'person' },
    )).rejects.toThrow('no longer available');

    expect(calls).toHaveLength(0);
  });
});

function setup(options: {
  timetable?: TimetableRunReader;
  snapshot?: (stationId: string) => Promise<CachedStationSnapshot | null>;
  plan?: JourneyPlanner['plan'];
} = {}) {
  const calls: Array<{ requestedAt?: string; originStationId?: string }> = [];
  const planner: JourneyPlanner = {
    plan: async (request, context) => {
      calls.push({
        requestedAt: request.requestedAt,
        originStationId: request.originStationId,
      });
      return options.plan
        ? options.plan(request, context)
        : plannerResponse([]);
    },
  };
  return {
    calls,
    module: createJourneyDepartureChoicesModule(
      planner,
      { now: () => now },
      {
        readTimetableRuns: options.timetable ?? scheduledRuns,
        readStationSnapshot: options.snapshot ?? (async () => null),
      },
    ),
  };
}

function input(
  value: Journey,
  selection?: JourneyDepartureChoicesInput['selection'],
): JourneyDepartureChoicesInput {
  return {
    journey: value,
    destination,
    policy: {
      requiredModes: [],
      excludedModes: [],
      preferredModes: [],
      requiresAccessibleStations: false,
      requiresOperationalElevators: false,
    },
    selection,
  };
}

function run(tripId: string, departure: string): TimetableRun {
  const departureAt = new Date(`2026-08-22T${departure}:00Z`);
  return {
    tripId,
    headsign: 'Destination',
    departureAt: departureAt.toISOString(),
    arrivalAt: new Date(departureAt.getTime() + 30 * 60_000).toISOString(),
  };
}

function epoch(time: string) {
  return Math.floor(Date.parse(`2026-08-22T${time}:00Z`) / 1_000);
}

function stationSnapshot(visits: CachedStationSnapshot['visits']): CachedStationSnapshot {
  return {
    visits,
    fetchedAt: epoch('09:58'),
    routes: [{
      id: 'line-a',
      shortName: 'A',
      mode: 'rer',
      color: '#FF0000',
      textColor: '#FFFFFF',
    }],
  };
}

function plannerResponse(journeys: Journey[]) {
  return {
    status: journeys.length > 0 ? ('ready' as const) : ('no-route' as const),
    source: 'idfm-realtime' as const,
    generatedAt: now.toISOString(),
    journeys,
  };
}

function connectingJourney(): Journey {
  const base = journey();
  const interchange = base.sections[1]!.to;
  const connection = transitSection(
    'connection',
    'line-b',
    interchange,
    { name: destination.name, coordinate: destination.coordinate },
    '2026-08-22T10:40:00Z',
    '2026-08-22T11:00:00Z',
    'connection-service',
    'station-b',
    destination.id,
  );
  return {
    ...base,
    arrivalAt: '2026-08-22T11:00:00Z',
    durationSeconds: 3_900,
    transferCount: 1,
    sections: [
      base.sections[0]!,
      base.sections[1]!,
      {
        id: 'connection-wait',
        type: 'wait',
        durationSeconds: 600,
        from: interchange,
        to: interchange,
        departureAt: '2026-08-22T10:30:00Z',
        arrivalAt: '2026-08-22T10:40:00Z',
        geometry: [],
        stops: [],
      },
      connection,
    ],
  };
}

function journey(
  id = 'current',
  transitDeparture = '2026-08-22T10:00:00Z',
  arrivalAt = '2026-08-22T10:30:00Z',
): Journey {
  const origin = { name: 'Origine', coordinate: { latitude: 48.8, longitude: 2.3 } };
  const station = { name: 'Station A', coordinate: { latitude: 48.81, longitude: 2.31 } };
  const alighting = { name: 'Station B', coordinate: { latitude: 48.85, longitude: 2.35 } };
  return {
    id,
    qualifier: 'recommended',
    durationSeconds: Math.round(
      (Date.parse(arrivalAt) - Date.parse('2026-08-22T09:55:00Z')) / 1_000,
    ),
    walkingDurationSeconds: 180,
    transferCount: 0,
    departureAt: '2026-08-22T09:55:00Z',
    arrivalAt,
    status: 'normal',
    warnings: [],
    sections: [
      {
        id: 'walk',
        type: 'walk',
        durationSeconds: 180,
        from: origin,
        to: station,
        departureAt: '2026-08-22T09:55:00Z',
        arrivalAt: '2026-08-22T09:58:00Z',
        geometry: [origin.coordinate, station.coordinate],
        stops: [],
      },
      transitSection(
        'ride',
        'line-a',
        station,
        alighting,
        transitDeparture,
        arrivalAt,
        id === 'current' ? 'trip-held' : `service-${id}`,
        'station-a',
        'station-b',
      ),
    ],
  };
}

function transitSection(
  id: string,
  routeId: string,
  from: JourneySection['from'],
  to: JourneySection['to'],
  departureAt: string,
  arrivalAt: string,
  serviceId: string,
  boardingStationId: string,
  alightingStationId: string,
): JourneySection {
  return {
    id,
    type: 'transit',
    durationSeconds: Math.round((Date.parse(arrivalAt) - Date.parse(departureAt)) / 1_000),
    from,
    to,
    departureAt,
    arrivalAt,
    geometry: [from.coordinate, to.coordinate],
    route: {
      id: routeId,
      shortName: routeId === 'line-a' ? 'A' : 'B',
      longName: routeId === 'line-a' ? 'Ligne A' : 'Ligne B',
      mode: 'rer',
      color: '#FF0000',
      textColor: '#FFFFFF',
    },
    direction: 'Destination',
    stops: [
      {
        id: `stop-${boardingStationId}`,
        stationId: boardingStationId,
        name: from.name,
        coordinate: from.coordinate,
        departureAt,
      },
      {
        id: `stop-${alightingStationId}`,
        stationId: alightingStationId,
        name: to.name,
        coordinate: to.coordinate,
        arrivalAt,
      },
    ],
    serviceId,
    timingSource: 'realtime',
  };
}

import { describe, expect, test } from 'bun:test';
import type { Journey, JourneyDepartureChoicesInput } from '@via/contract';

import { createJourneyDepartureChoicesModule } from './departure-choices';
import type { JourneyPlanner } from './service';
import type { TimetableRunReader } from './timetable-runs';

/** Most tests exercise planner discovery alone; the schedule stays silent. */
const noTimetableRuns: TimetableRunReader = async () => [];

/** A quarter-hourly line, with one run already gone by the time it is read. */
const scheduledRuns: TimetableRunReader = async () => [
  run('trip-gone', '09:52'),
  run('trip-1', '10:05'),
  run('trip-2', '10:12'),
  run('trip-3', '10:19'),
  run('trip-4', '10:26'),
];

function run(tripId: string, departure: string) {
  const departureAt = new Date(`2026-08-22T${departure}:00Z`);
  return {
    tripId,
    headsign: 'Destination',
    departureAt: departureAt.toISOString(),
    arrivalAt: new Date(departureAt.getTime() + 1_800_000).toISOString(),
  };
}

const destination = {
  kind: 'station' as const,
  id: 'destination',
  name: 'Destination',
  coordinate: { latitude: 48.9, longitude: 2.4 },
};

const current = journey('current', '2026-08-22T10:00:00Z', '2026-08-22T10:30:00Z');
const next = journey('next', '2026-08-22T10:05:00Z', '2026-08-22T10:35:00Z');

function input(selection?: JourneyDepartureChoicesInput['selection']): JourneyDepartureChoicesInput {
  return {
    journey: current,
    destination,
    policy: {
      requiredModes: [],
      excludedModes: [],
      preferredModes: [],
      requiresAccessibleStations: false,
    },
    selection,
  };
}

function setup(
  result: Journey[] = [next],
  source: 'idfm-realtime' | 'gtfs-theoretical' = 'idfm-realtime',
  timetable: TimetableRunReader = noTimetableRuns
) {
  const calls: Array<{ requestedAt?: string; originStationId?: string }> = [];
  const planner: JourneyPlanner = {
    plan: async (request) => {
      calls.push({ requestedAt: request.requestedAt, originStationId: request.originStationId });
      return {
        status: result.length ? 'ready' : 'no-route',
        source,
        generatedAt: '2026-08-22T09:59:00Z',
        journeys: result,
      };
    },
  };
  return {
    calls,
    module: createJourneyDepartureChoicesModule(
      planner,
      { now: () => new Date('2026-08-22T09:59:00Z') },
      timetable
    ),
  };
}

describe('journey departure choices module', () => {
  test('returns the selected departure and the immediate matching next one', async () => {
    const { module, calls } = setup();

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.groups).toHaveLength(1);
    expect(response.groups[0]).toMatchObject({
      sectionId: 'ride',
      availability: 'ready',
      source: 'realtime',
      choices: [
        { scheduledAt: '2026-08-22T10:00:00Z', isSelected: true },
        { scheduledAt: '2026-08-22T10:05:00Z', isSelected: false },
      ],
    });
    expect(calls[0]?.originStationId).toBe('station-a');
  });

  test('asks again after the selected departure when the first plan hid the next service', async () => {
    const calls: string[] = [];
    const planner: JourneyPlanner = {
      plan: async (request) => {
        calls.push(request.requestedAt!);
        // The planner prunes the later same-line service as dominated until it
        // is asked from a time the boarded one can no longer answer.
        const journeys = Date.parse(request.requestedAt!) > Date.parse('2026-08-22T10:00:00Z')
          ? [next]
          : [current];
        return {
          status: 'ready',
          source: 'gtfs-theoretical',
          generatedAt: '2026-08-22T09:59:00Z',
          journeys,
        };
      },
    };
    const module = createJourneyDepartureChoicesModule(
      planner,
      { now: () => new Date('2026-08-22T09:59:00Z') },
      noTimetableRuns
    );

    const response = await module.resolve(input(), { identity: 'person' });

    expect(calls).toEqual([
      '2026-08-22T09:55:00.000Z',
      '2026-08-22T10:01:00.000Z',
      // The backwards pass, anchored on an arrival a minute before the held one.
      '2026-08-22T10:29:00.000Z',
    ]);
    expect(response.groups[0]).toMatchObject({ availability: 'ready' });
    expect(response.groups[0]?.choices).toMatchObject([
      { scheduledAt: '2026-08-22T10:00:00Z', isSelected: true },
      { scheduledAt: '2026-08-22T10:05:00Z', isSelected: false },
    ]);
  });

  test('offers the service before the held one and lets it be chosen back', async () => {
    const earlier = journey('earlier', '2026-08-22T09:57:00Z', '2026-08-22T10:27:00Z');
    const planner: JourneyPlanner = {
      plan: async (request) => ({
        status: 'ready',
        source: 'gtfs-theoretical',
        generatedAt: '2026-08-22T09:55:00Z',
        // Only the backwards, arrival-anchored pass sees the earlier service.
        journeys: request.datetimeRepresents === 'arrival' ? [earlier] : [next],
      }),
    };
    const module = createJourneyDepartureChoicesModule(
      planner,
      { now: () => new Date('2026-08-22T09:55:00Z') },
      noTimetableRuns
    );

    const choices = await module.resolve(input(), { identity: 'person' });

    expect(choices.groups[0]?.choices).toMatchObject([
      { scheduledAt: '2026-08-22T09:57:00Z', isSelected: false },
      { scheduledAt: '2026-08-22T10:00:00Z', isSelected: true },
      { scheduledAt: '2026-08-22T10:05:00Z', isSelected: false },
    ]);

    const response = await module.resolve(
      input({ sectionId: 'ride', departureId: choices.groups[0]!.choices[0]!.id }),
      { identity: 'person' }
    );

    expect(response.journey.sections[1]?.departureAt).toBe('2026-08-22T09:57:00Z');
    expect(response.journey.arrivalAt).toBe('2026-08-22T10:27:00Z');
  });

  test('never offers a service that has already left', async () => {
    const departed = journey('departed', '2026-08-22T09:57:00Z', '2026-08-22T10:27:00Z');
    const planner: JourneyPlanner = {
      plan: async (request) => ({
        status: 'ready',
        source: 'gtfs-theoretical',
        generatedAt: '2026-08-22T09:59:00Z',
        journeys: request.datetimeRepresents === 'arrival' ? [departed] : [],
      }),
    };
    const module = createJourneyDepartureChoicesModule(
      planner,
      { now: () => new Date('2026-08-22T09:59:00Z') },
      noTimetableRuns
    );

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.groups[0]?.choices).toHaveLength(1);
    expect(response.groups[0]).toMatchObject({ availability: 'unavailable' });
  });

  test('keeps the revised selected service when the second pass fails', async () => {
    const delayed = journey('current-revised', '2026-08-22T10:03:00Z', '2026-08-22T10:33:00Z');
    delayed.sections = delayed.sections.map((section) => section.type === 'transit'
      ? { ...section, serviceId: 'service-current' }
      : section);
    const planner: JourneyPlanner = {
      plan: async (request) => {
        if (Date.parse(request.requestedAt!) > Date.parse('2026-08-22T10:00:00Z')) {
          throw new Error('provider down');
        }
        return {
          status: 'ready',
          source: 'idfm-realtime',
          generatedAt: '2026-08-22T09:59:00Z',
          journeys: [delayed],
        };
      },
    };
    const module = createJourneyDepartureChoicesModule(
      planner,
      { now: () => new Date('2026-08-22T09:59:00Z') },
      noTimetableRuns
    );

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.journey.sections[1]?.departureAt).toBe('2026-08-22T10:03:00Z');
    expect(response.groups[0]).toMatchObject({ availability: 'unavailable' });
  });

  test('keeps the journey unchanged when no matching next service exists', async () => {
    const differentLine = {
      ...next,
      sections: next.sections.map((section) => section.type === 'transit'
        ? { ...section, route: { ...section.route!, id: 'line-b', shortName: 'B' } }
        : section),
    };
    const { module } = setup([differentLine]);

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.journey).toEqual(current);
    expect(response.groups[0]).toMatchObject({ availability: 'unavailable' });
    expect(response.groups[0]?.choices).toHaveLength(1);
  });

  test('offers another mission of the same line that still serves the alighting stop', async () => {
    // Consecutive RER services towards the same platform carry different
    // mission codes; treating the headsign as identity hid every alternative.
    const otherMission = {
      ...next,
      sections: next.sections.map((section) => section.type === 'transit'
        ? { ...section, direction: 'ELBA' }
        : section),
    };
    const { module } = setup([otherMission]);

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.groups[0]).toMatchObject({ availability: 'ready' });
    expect(response.groups[0]?.choices).toMatchObject([
      { scheduledAt: '2026-08-22T10:00:00Z', isSelected: true },
      { scheduledAt: '2026-08-22T10:05:00Z', isSelected: false },
    ]);
  });

  test('filters candidates that never call at the alighting stop', async () => {
    const wrongAlighting = {
      ...next,
      id: 'wrong-stop',
      sections: next.sections.map((section) => section.type === 'transit'
        ? {
            ...section,
            to: { ...section.to, name: 'Station C' },
            stops: section.stops.map((stop, index) => index === section.stops.length - 1
              ? { ...stop, id: 'stop-c', stationId: 'station-c', name: 'Station C' }
              : stop),
          }
        : section),
    };
    const { module } = setup([wrongAlighting]);

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.groups[0]).toMatchObject({ availability: 'unavailable' });
    expect(response.groups[0]?.choices).toHaveLength(1);
  });

  test('marks a fallback next service as theoretical without relabelling the selected realtime one', async () => {
    const theoreticalNext = {
      ...next,
      sections: next.sections.map((section) => section.type === 'transit'
        ? { ...section, timingSource: 'theoretical' as const }
        : section),
    };
    const { module } = setup([theoreticalNext], 'gtfs-theoretical');

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.groups[0]?.choices).toMatchObject([
      { source: 'realtime', isSelected: true },
      { source: 'theoretical', status: 'scheduled', isSelected: false },
    ]);
  });

  test('atomically revises the selected realtime service and its downstream timings', async () => {
    const delayed = journey(
      'current-revised',
      '2026-08-22T10:03:00Z',
      '2026-08-22T10:33:00Z'
    );
    delayed.sections = delayed.sections.map((section) => section.type === 'transit'
      ? {
          ...section,
          serviceId: 'service-current',
          scheduledDepartureAt: '2026-08-22T10:00:00Z',
          scheduledArrivalAt: '2026-08-22T10:30:00Z',
        }
      : section);
    const { module } = setup([delayed, next]);

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.journey.id).toBe(current.id);
    expect(response.journey.sections[0]).toEqual(current.sections[0]);
    expect(response.journey.sections[1]?.departureAt).toBe('2026-08-22T10:03:00Z');
    expect(response.journey.arrivalAt).toBe('2026-08-22T10:33:00Z');
    expect(response.groups[0]?.choices[0]).toMatchObject({
      scheduledAt: '2026-08-22T10:00:00Z',
      expectedAt: '2026-08-22T10:03:00Z',
      status: 'delayed',
      isSelected: true,
    });
  });

  test('preserves the upstream section and replaces the selected leg plus downstream', async () => {
    const { module } = setup();
    const choices = await module.resolve(input(), { identity: 'person' });
    const nextId = choices.groups[0]?.choices[1]?.id;
    expect(nextId).toBeDefined();

    const response = await module.resolve(
      input({ sectionId: 'ride', departureId: nextId! }),
      { identity: 'person' }
    );

    expect(response.journey.id).toBe(current.id);
    expect(response.journey.sections[0]).toEqual(current.sections[0]);
    expect(response.journey.sections[1]?.id).toBe('ride');
    expect(response.journey.sections[1]?.departureAt).toBe('2026-08-22T10:05:00Z');
    expect(response.journey.arrivalAt).toBe('2026-08-22T10:35:00Z');
  });

  test('recomputes the wait before the chosen service while preserving the physical prefix', async () => {
    const oldWait = {
      id: 'wait',
      type: 'wait' as const,
      durationSeconds: 180,
      from: current.sections[1]!.from,
      to: current.sections[1]!.from,
      departureAt: '2026-08-22T09:57:00Z',
      arrivalAt: '2026-08-22T10:00:00Z',
      geometry: [],
      stops: [],
    };
    const currentWithWait: Journey = {
      ...current,
      sections: [
        { ...current.sections[0]!, arrivalAt: '2026-08-22T09:57:00Z' },
        oldWait,
        current.sections[1]!,
      ],
    };
    const { module } = setup();
    const request = { ...input(), journey: currentWithWait };
    const choices = await module.resolve(request, { identity: 'person' });

    const response = await module.resolve({
      ...request,
      selection: {
        sectionId: 'ride',
        departureId: choices.groups[0]!.choices[1]!.id,
      },
    }, { identity: 'person' });

    expect(response.journey.sections[0]).toEqual(currentWithWait.sections[0]);
    expect(response.journey.sections[1]).toMatchObject({
      id: 'wait',
      type: 'wait',
      durationSeconds: 480,
      arrivalAt: '2026-08-22T10:05:00Z',
    });
    expect(response.journey.sections[2]).toMatchObject({
      id: 'ride',
      departureAt: '2026-08-22T10:05:00Z',
    });
  });

  test('offers the passages the schedule knows when the planner prunes them all', async () => {
    // The planner drops a later train on the same line as dominated, so
    // discovery through planning alone can only ever surface one alternative.
    const { module } = setup([], 'gtfs-theoretical', scheduledRuns);

    const response = await module.resolve(input(), { identity: 'person' });

    expect(response.groups[0]).toMatchObject({ availability: 'ready' });
    expect(response.groups[0]?.choices).toMatchObject([
      { scheduledAt: '2026-08-22T10:00:00Z', isSelected: true },
      { scheduledAt: '2026-08-22T10:05:00.000Z', isSelected: false },
      { scheduledAt: '2026-08-22T10:12:00.000Z', isSelected: false },
      { scheduledAt: '2026-08-22T10:19:00.000Z', isSelected: false },
    ]);
  });

  test('plans the scheduled passage the traveller picks and splices it in', async () => {
    const planner: JourneyPlanner = {
      plan: async (request) => ({
        status: 'ready',
        source: 'gtfs-theoretical',
        generatedAt: '2026-08-22T09:59:00Z',
        // Only an anchor sitting on that run answers with it.
        journeys: request.requestedAt === '2026-08-22T10:04:00.000Z' ? [next] : [],
      }),
    };
    const module = createJourneyDepartureChoicesModule(
      planner,
      { now: () => new Date('2026-08-22T09:59:00Z') },
      scheduledRuns
    );

    const response = await module.resolve(
      input({ sectionId: 'ride', departureId: 'departure:ride:trip-1' }),
      { identity: 'person' }
    );

    expect(response.journey.sections[1]?.departureAt).toBe('2026-08-22T10:05:00Z');
    expect(response.journey.arrivalAt).toBe('2026-08-22T10:35:00Z');
  });

  test('never offers a passage that leaves before the traveller reaches the platform', async () => {
    const walking: Journey = {
      ...current,
      sections: [
        { ...current.sections[0]!, arrivalAt: '2026-08-22T10:08:00Z' },
        current.sections[1]!,
      ],
    };
    const { module } = setup([], 'gtfs-theoretical', scheduledRuns);

    const response = await module.resolve(
      { ...input(), journey: walking },
      { identity: 'person' }
    );

    // 10:05 is still walking time; the rail starts at the run after it.
    expect(response.groups[0]?.choices).toMatchObject([
      { scheduledAt: '2026-08-22T10:00:00Z', isSelected: true },
      { scheduledAt: '2026-08-22T10:12:00.000Z', isSelected: false },
      { scheduledAt: '2026-08-22T10:19:00.000Z', isSelected: false },
      { scheduledAt: '2026-08-22T10:26:00.000Z', isSelected: false },
    ]);
  });

  test('rejects a departure that disappeared without returning a mutated journey', async () => {
    const { module } = setup([]);

    await expect(module.resolve(
      input({ sectionId: 'ride', departureId: 'gone' }),
      { identity: 'person' }
    )).rejects.toThrow('no longer available');
  });
});

function journey(id: string, transitDeparture: string, arrivalAt: string): Journey {
  const origin = { name: 'Origine', coordinate: { latitude: 48.8, longitude: 2.3 } };
  const station = { name: 'Station A', coordinate: { latitude: 48.81, longitude: 2.31 } };
  const alighting = { name: 'Station B', coordinate: { latitude: 48.85, longitude: 2.35 } };
  return {
    id,
    qualifier: 'recommended',
    durationSeconds: 2_400,
    walkingDurationSeconds: 300,
    transferCount: 0,
    departureAt: '2026-08-22T09:55:00Z',
    arrivalAt,
    status: 'normal',
    warnings: [],
    sections: [
      {
        id: 'walk',
        type: 'walk',
        durationSeconds: 300,
        from: origin,
        to: station,
        geometry: [origin.coordinate, station.coordinate],
        stops: [],
      },
      {
        id: 'ride',
        type: 'transit',
        durationSeconds: 1_200,
        from: station,
        to: alighting,
        departureAt: transitDeparture,
        arrivalAt,
        geometry: [station.coordinate, alighting.coordinate],
        route: {
          id: 'line-a',
          shortName: 'A',
          longName: 'Ligne A',
          mode: 'rer',
          color: '#FF0000',
          textColor: '#FFFFFF',
        },
        direction: 'Destination',
        stops: [
          {
            id: 'stop-a',
            stationId: 'station-a',
            name: 'Station A',
            coordinate: station.coordinate,
            departureAt: transitDeparture,
          },
          {
            id: 'stop-b',
            stationId: 'station-b',
            name: 'Station B',
            coordinate: alighting.coordinate,
            arrivalAt,
          },
        ],
        serviceId: `service-${id}`,
        timingSource: 'realtime',
      },
    ],
  };
}

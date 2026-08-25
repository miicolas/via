import { describe, expect, test } from 'bun:test';
import type { Journey, JourneyInput, JourneysResponse } from '@via/contract';

import { withLastDeparture } from './last-departure';
import type { JourneyPlanner } from './service';
import type { TimetableRun, TimetableRunQuery } from './timetable-runs';

const COORD = { latitude: 48.85, longitude: 2.35 };

const INPUT: JourneyInput = {
  origin: COORD,
  destination: { kind: 'station', id: 'stop_dest', name: 'La Défense', coordinate: COORD },
  limit: 4,
  // 22:00 Paris (20:00Z in August): well inside the evening service.
  requestedAt: '2026-08-21T20:00:00.000Z',
  timeAnchor: 'last_of_day',
};

function journeyAt(departureAt: string, sections: Journey['sections']): Journey {
  return {
    id: `journey_${departureAt}`,
    qualifier: 'recommended',
    durationSeconds: 1800,
    walkingDurationSeconds: 300,
    transferCount: 0,
    departureAt,
    arrivalAt: '2026-08-22T00:45:00.000Z',
    status: 'normal',
    warnings: [],
    sections,
  } as Journey;
}

function transitJourney(departureAt: string): Journey {
  return journeyAt(departureAt, [
    {
      type: 'transit',
      durationSeconds: 1500,
      from: { name: 'Châtelet', coordinate: COORD },
      to: { name: 'La Défense', coordinate: COORD },
      departureAt,
      geometry: [],
      route: {
        id: 'route_m1',
        shortName: '1',
        longName: 'La Défense – Château de Vincennes',
        mode: 'metro',
        color: '#FFBE00',
        textColor: '#000000',
      },
      stops: [
        { id: 'boarding_stop', stationId: 'station_chatelet', name: 'Châtelet', coordinate: COORD },
        { id: 'alighting_stop', stationId: 'station_defense', name: 'La Défense', coordinate: COORD },
      ],
    },
  ] as Journey['sections']);
}

function ready(journeys: Journey[]): JourneysResponse {
  return {
    status: 'ready',
    source: 'gtfs-theoretical',
    generatedAt: '2026-08-21T20:00:00.000Z',
    journeys,
  };
}

function fakePlanner(responses: JourneysResponse[]) {
  const calls: JourneyInput[] = [];
  const planner: JourneyPlanner = {
    plan: async (input) => {
      calls.push(input);
      const response = responses[Math.min(calls.length - 1, responses.length - 1)];
      if (!response) throw new Error('no scripted response');
      return response;
    },
  };
  return { planner, calls };
}

function fakeRuns(runs: TimetableRun[]) {
  const queries: TimetableRunQuery[] = [];
  return {
    queries,
    read: async (query: TimetableRunQuery) => {
      queries.push(query);
      return runs;
    },
  };
}

describe('withLastDeparture', () => {
  test('inputs without the anchor pass straight through', async () => {
    const base = ready([transitJourney('2026-08-21T20:10:00.000Z')]);
    const { planner, calls } = fakePlanner([base]);
    const runs = fakeRuns([]);
    const decorated = withLastDeparture(planner, { readTimetableRuns: runs.read });

    const { timeAnchor: _anchor, ...plain } = INPUT;
    const result = await decorated.plan(plain, { identity: 'user-1' });

    expect(result).toBe(base);
    expect(calls[0]).toEqual(plain);
    expect(runs.queries).toHaveLength(0);
  });

  test('plans an arrival at the end of the service day, anchor stripped', async () => {
    const base = ready([transitJourney('2026-08-22T00:10:00.000Z')]);
    const { planner, calls } = fakePlanner([base]);
    const runs = fakeRuns([]);
    const decorated = withLastDeparture(planner, { readTimetableRuns: runs.read });

    await decorated.plan(INPUT, { identity: 'user-1' });

    // 27:00 on the 2026-08-21 service day = 03:00 Paris on the 22nd = 01:00Z (DST).
    expect(calls[0]!.requestedAt).toBe('2026-08-22T01:00:00.000Z');
    expect(calls[0]!.datetimeRepresents).toBe('arrival');
    expect(calls[0]!.timeAnchor).toBeUndefined();
  });

  test('just after midnight still belongs to the previous service day', async () => {
    const base = ready([transitJourney('2026-08-22T00:10:00.000Z')]);
    const { planner, calls } = fakePlanner([base]);
    const runs = fakeRuns([]);
    const decorated = withLastDeparture(planner, { readTimetableRuns: runs.read });

    // 00:30 Paris on the 22nd (22:30Z on the 21st).
    await decorated.plan({ ...INPUT, requestedAt: '2026-08-21T22:30:00.000Z' }, { identity: 'u' });

    expect(calls[0]!.requestedAt).toBe('2026-08-22T01:00:00.000Z');
  });

  test('a later GTFS run triggers a departure-anchored replan that wins', async () => {
    const base = ready([transitJourney('2026-08-22T00:10:00.000Z')]);
    const retimed = ready([transitJourney('2026-08-22T00:32:00.000Z')]);
    const { planner, calls } = fakePlanner([base, retimed]);
    const runs = fakeRuns([
      {
        tripId: 'trip_late',
        headsign: 'La Défense',
        departureAt: '2026-08-22T00:32:00.000Z',
        arrivalAt: '2026-08-22T00:57:00.000Z',
      },
    ]);
    const decorated = withLastDeparture(planner, { readTimetableRuns: runs.read });

    const result = await decorated.plan(INPUT, { identity: 'user-1' });

    expect(calls).toHaveLength(2);
    expect(calls[1]!.requestedAt).toBe('2026-08-22T00:32:00.000Z');
    expect(calls[1]!.datetimeRepresents).toBe('departure');
    expect(result).toBe(retimed);
    // The timetable was scanned from the planned boarding to end of service.
    expect(runs.queries[0]!.routeId).toBe('route_m1');
    expect(runs.queries[0]!.boardingStopIds).toEqual(['station_chatelet', 'boarding_stop']);
    expect(runs.queries[0]!.to.toISOString()).toBe('2026-08-22T01:00:00.000Z');
  });

  test('no later run keeps the arrival-anchored answer without replanning', async () => {
    const base = ready([transitJourney('2026-08-22T00:10:00.000Z')]);
    const { planner, calls } = fakePlanner([base]);
    const runs = fakeRuns([
      {
        tripId: 'trip_same',
        headsign: 'La Défense',
        departureAt: '2026-08-22T00:10:00.000Z',
        arrivalAt: '2026-08-22T00:35:00.000Z',
      },
    ]);
    const decorated = withLastDeparture(planner, { readTimetableRuns: runs.read });

    const result = await decorated.plan(INPUT, { identity: 'user-1' });

    expect(result).toBe(base);
    expect(calls).toHaveLength(1);
  });

  test('a journey without a transit section skips the timetable entirely', async () => {
    const walkOnly = ready([
      journeyAt('2026-08-22T00:10:00.000Z', [
        {
          type: 'walk',
          durationSeconds: 900,
          from: { name: 'A', coordinate: COORD },
          to: { name: 'B', coordinate: COORD },
          geometry: [],
          stops: [],
        },
      ] as Journey['sections']),
    ]);
    const { planner, calls } = fakePlanner([walkOnly]);
    const runs = fakeRuns([]);
    const decorated = withLastDeparture(planner, { readTimetableRuns: runs.read });

    const result = await decorated.plan(INPUT, { identity: 'user-1' });

    expect(result).toBe(walkOnly);
    expect(calls).toHaveLength(1);
    expect(runs.queries).toHaveLength(0);
  });

  test('a replan that cannot connect leaves the arrival answer standing', async () => {
    const base = ready([transitJourney('2026-08-22T00:10:00.000Z')]);
    const failed: JourneysResponse = {
      status: 'no-route',
      source: 'gtfs-theoretical',
      generatedAt: '2026-08-21T20:00:00.000Z',
      journeys: [],
    };
    const { planner } = fakePlanner([base, failed]);
    const runs = fakeRuns([
      {
        tripId: 'trip_late',
        headsign: 'La Défense',
        departureAt: '2026-08-22T00:40:00.000Z',
        arrivalAt: '2026-08-22T01:05:00.000Z',
      },
    ]);
    const decorated = withLastDeparture(planner, { readTimetableRuns: runs.read });

    const result = await decorated.plan(INPUT, { identity: 'user-1' });

    expect(result).toBe(base);
  });
});

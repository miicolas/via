import { describe, expect, test } from 'bun:test';
import type { Journey, JourneyInput, JourneyMode, JourneysResponse } from '@via/contract';

import { fakeRedis } from '../departures/__fixtures__/fake-redis';
import {
  createJourneyPlanner,
  type GtfsJourneyPlanner,
  type IdfmJourneyPlanner,
} from './service';

const now = new Date('2026-08-12T10:00:00Z');
const input: JourneyInput = {
  origin: { latitude: 48.8566, longitude: 2.3522 },
  destination: {
    kind: 'station',
    id: 'IDFM:71264',
    name: 'Châtelet',
    coordinate: { latitude: 48.8584, longitude: 2.347 },
  },
  limit: 4,
};

const realtime = { status: 'ready' as const, journeys: [] };
const theoretical = { status: 'no-route' as const, journeys: [] };

function setup(options: {
  apiKey?: boolean;
  idfmResult?: Awaited<ReturnType<IdfmJourneyPlanner['plan']>>;
  idfmResults?: Array<Awaited<ReturnType<IdfmJourneyPlanner['plan']>>>;
  gtfsError?: Error;
  personalLimit?: number;
  dailyBudget?: number;
} = {}) {
  const { client, store, expiries } = fakeRedis();
  let currentNow = now;
  const calls = { idfm: 0, gtfs: 0 };
  const signals: Array<AbortSignal | undefined> = [];
  const idfm: IdfmJourneyPlanner = {
    plan: async (_input, _now, signal) => {
      calls.idfm += 1;
      signals.push(signal);
      return options.idfmResults?.[calls.idfm - 1] ??
        (options.idfmResult === undefined ? realtime : options.idfmResult);
    },
  };
  const gtfs: GtfsJourneyPlanner = {
    plan: async (_input, _now, signal) => {
      calls.gtfs += 1;
      signals.push(signal);
      if (options.gtfsError) throw options.gtfsError;
      return theoretical;
    },
  };
  const planner = createJourneyPlanner({
    redis: client,
    idfm: options.apiKey === false ? null : idfm,
    gtfs,
    clock: { now: () => currentNow },
    config: {
      personalLimit: options.personalLimit ?? 20,
      personalWindowSeconds: 900,
      dailyBudget: options.dailyBudget ?? 1_000,
    },
  });

  return {
    planner,
    client,
    store,
    expiries,
    calls,
    signals,
    advance: (milliseconds: number) => {
      currentNow = new Date(currentNow.getTime() + milliseconds);
    },
  };
}

const plan = (
  planner: ReturnType<typeof createJourneyPlanner>,
  signal?: AbortSignal,
  journeyInput = input
) => planner.plan(journeyInput, { identity: 'person-a', signal });

function cachedResponse(store: Map<string, unknown>) {
  return [...store.entries()].find(([key]) => key.startsWith('journeys:cache:'))?.[1] as
    | JourneysResponse
    | undefined;
}

function cachedTtl(expiries: Map<string, number>) {
  return [...expiries.entries()].find(([key]) => key.startsWith('journeys:cache:'))?.[1];
}

describe('journey planning module', () => {
  test('returns a cache hit without consulting either planner', async () => {
    const { planner, calls } = setup();

    const first = await plan(planner);
    const second = await plan(planner);

    expect(second).toEqual(first);
    expect(calls).toEqual({ idfm: 1, gtfs: 0 });
  });

  test('uses GTFS with the short TTL when no IDFM key is configured', async () => {
    const { planner, calls, expiries } = setup({ apiKey: false });

    const response = await plan(planner);

    expect(response).toMatchObject({ status: 'no-route', source: 'gtfs-theoretical' });
    expect(calls).toEqual({ idfm: 0, gtfs: 1 });
    expect(cachedTtl(expiries)).toBe(30);
  });

  test('uses GTFS when the personal quota refuses the request', async () => {
    const { planner, calls, expiries, advance } = setup({ personalLimit: 1 });
    await plan(planner);
    advance(60_000);

    const response = await plan(planner);

    expect(response).toMatchObject({ status: 'no-route', source: 'gtfs-theoretical' });
    expect(calls).toEqual({ idfm: 1, gtfs: 1 });
    expect([...expiries.values()]).toContain(30);
  });

  test('uses GTFS when the daily quota refuses the request', async () => {
    const { planner, calls, expiries } = setup({ dailyBudget: 0 });

    const response = await plan(planner);

    expect(response).toMatchObject({ status: 'no-route', source: 'gtfs-theoretical' });
    expect(calls).toEqual({ idfm: 0, gtfs: 1 });
    expect(cachedTtl(expiries)).toBe(30);
  });

  test('qualifies an IDFM response and caches it for the realtime TTL', async () => {
    const { planner, calls, expiries } = setup();

    const response = await plan(planner);

    expect(response).toEqual({
      status: 'no-route',
      source: 'idfm-realtime',
      generatedAt: now.toISOString(),
      journeys: [],
    });
    expect(calls).toEqual({ idfm: 1, gtfs: 0 });
    expect(cachedTtl(expiries)).toBe(45);
  });

  test('keeps the realtime TTL when IDFM fails and GTFS takes over', async () => {
    const { planner, calls, expiries } = setup({ idfmResult: null });

    const response = await plan(planner);

    expect(response).toMatchObject({ status: 'no-route', source: 'gtfs-theoretical' });
    expect(calls).toEqual({ idfm: 1, gtfs: 1 });
    expect(cachedTtl(expiries)).toBe(45);
  });

  test('returns unavailable when GTFS fails', async () => {
    const { planner } = setup({ apiKey: false, gtfsError: new Error('postgres down') });

    await expect(plan(planner)).resolves.toEqual({
      status: 'unavailable',
      source: 'gtfs-theoretical',
      generatedAt: now.toISOString(),
      journeys: [],
    });
  });

  test('returns unavailable on a Redis outage without trying GTFS', async () => {
    const { planner, client, calls } = setup({ apiKey: false });
    client.get = async () => {
      throw new Error('redis down');
    };

    const response = await plan(planner);

    expect(response).toMatchObject({ status: 'unavailable' });
    expect(calls).toEqual({ idfm: 0, gtfs: 0 });
  });

  test('propagates the request cancellation signal to upstream planners', async () => {
    const controller = new AbortController();
    const { planner, signals } = setup({ idfmResult: null });

    await plan(planner, controller.signal);

    expect(signals).toEqual([controller.signal, controller.signal]);
  });

  test('stores the response produced through the public interface', async () => {
    const { planner, store } = setup({ apiKey: false });

    const response = await plan(planner);

    expect(cachedResponse(store)).toEqual(response);
  });

  test('makes at most one extra filtered IDFM request for a soft mode preference', async () => {
    const metro = modalJourney('metro', 1_800);
    const bus = modalJourney('bus', 2_000);
    const { planner, calls } = setup({
      idfmResults: [
        { status: 'ready', journeys: [metro] },
        { status: 'ready', journeys: [bus] },
      ],
    });
    const response = await plan(planner, undefined, { ...input, preferredModes: ['bus'] });

    expect(calls.idfm).toBe(2);
    expect(response.journeys[0]?.id).toBe('bus');
  });

  test('keeps a wheelchair IDFM detour without requiring local station facts', async () => {
    const detour = modalJourney('bus', 3_600);
    const { planner, calls } = setup({
      idfmResult: { status: 'ready', journeys: [detour] },
    });

    const response = await plan(planner, undefined, {
      ...input,
      destination: {
        kind: 'address',
        id: 'rue-de-chabrol',
        name: 'Rue de Chabrol',
        coordinate: { latitude: 48.8762, longitude: 2.3517 },
      },
      requiresAccessibleStations: true,
    });

    expect(response).toMatchObject({ status: 'ready', source: 'idfm-realtime' });
    expect(response.journeys.map((journey) => journey.id)).toEqual(['bus']);
    expect(calls).toEqual({ idfm: 1, gtfs: 0 });
  });
});

function modalJourney(mode: JourneyMode, durationSeconds: number): Journey {
  return {
    id: mode,
    qualifier: 'recommended',
    durationSeconds,
    walkingDurationSeconds: 60,
    transferCount: 0,
    departureAt: '2026-08-12T10:05:00Z',
    arrivalAt: new Date(Date.parse('2026-08-12T10:05:00Z') + durationSeconds * 1_000).toISOString(),
    status: 'normal',
    warnings: [],
    sections: [{
      type: 'transit',
      durationSeconds,
      from: { name: 'Départ', coordinate: input.origin },
      to: { name: input.destination.name, coordinate: input.destination.coordinate },
      geometry: [],
      route: { id: mode, shortName: '1', longName: mode, mode, color: '#000', textColor: '#fff' },
      stops: [],
    }],
  };
}

import { describe, expect, test } from 'bun:test';
import type { Journey, JourneyInput, JourneyMode, JourneysResponse } from '@via/contract';

import { fakeRedis } from '../departures/__fixtures__/fake-redis';
import {
  createJourneyPlanner,
  rankPreferredJourney,
  type GtfsJourneyPlanner,
  type JourneyDisruptionOverlay,
  type IdfmJourneyPlanner,
  type JourneyReportOverlay,
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
  gtfsDelayMs?: number;
  personalLimit?: number;
  dailyBudget?: number;
  reports?: JourneyReportOverlay;
  disruptions?: JourneyDisruptionOverlay;
} = {}) {
  const { client, store, expiries } = fakeRedis();
  let currentNow = now;
  const calls = { idfm: 0, gtfs: 0 };
  const gtfsConcurrency = { active: 0, max: 0 };
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
      gtfsConcurrency.active += 1;
      gtfsConcurrency.max = Math.max(gtfsConcurrency.max, gtfsConcurrency.active);
      try {
        if (options.gtfsDelayMs) {
          await new Promise((resolve) => setTimeout(resolve, options.gtfsDelayMs));
        }
        if (options.gtfsError) throw options.gtfsError;
        return theoretical;
      } finally {
        gtfsConcurrency.active -= 1;
      }
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
    reports: options.reports,
    disruptions: options.disruptions,
  });

  return {
    planner,
    client,
    store,
    expiries,
    calls,
    gtfsConcurrency,
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

  test('reapplies live reports to the same stable cached plan', async () => {
    let people = 1;
    const journey = modalJourney('metro', 1_800);
    const reports: JourneyReportOverlay = {
      apply: async (response) => ({
        ...response,
        journeys: response.journeys.map((value) => ({
          ...value,
          wheelchairReport: {
            stationName: 'Châtelet',
            label: 'Accès PMR signalé indisponible',
            reporterCount: people,
            confidence: people >= 2 ? 'confirmed' : 'observed',
            expiresAt: '2026-08-12T11:00:00Z',
          },
        })),
      }),
    };
    const { planner, calls } = setup({
      idfmResult: { status: 'ready', journeys: [journey] },
      reports,
    });

    const first = await plan(planner);
    people = 2;
    const second = await plan(planner);

    expect(first.journeys[0]?.wheelchairReport?.reporterCount).toBe(1);
    expect(second.journeys[0]?.wheelchairReport?.reporterCount).toBe(2);
    expect(calls.idfm).toBe(1);
  });

  test('reapplies official disruptions to the same stable cached plan', async () => {
    let warning = 'Perturbation officielle initiale';
    const journey = modalJourney('metro', 1_800);
    const disruptions: JourneyDisruptionOverlay = {
      apply: async (response) => ({
        ...response,
        journeys: response.journeys.map((value) => ({
          ...value,
          status: 'disrupted' as const,
          warnings: [warning],
        })),
      }),
    };
    const { planner, calls } = setup({
      idfmResult: { status: 'ready', journeys: [journey] },
      disruptions,
    });

    const first = await plan(planner);
    warning = 'Perturbation officielle actualisée';
    const second = await plan(planner);

    expect(first.journeys[0]?.warnings).toEqual(['Perturbation officielle initiale']);
    expect(second.journeys[0]?.warnings).toEqual(['Perturbation officielle actualisée']);
    expect(calls.idfm).toBe(1);
  });

  test('uses GTFS with the short TTL when no IDFM key is configured', async () => {
    const { planner, calls, expiries } = setup({ apiKey: false });

    const response = await plan(planner);

    expect(response).toMatchObject({ status: 'no-route', source: 'gtfs-theoretical' });
    expect(calls).toEqual({ idfm: 0, gtfs: 1 });
    expect(cachedTtl(expiries)).toBe(30);
  });

  test('serializes concurrent GTFS fallbacks', async () => {
    const { planner, gtfsConcurrency } = setup({ apiKey: false, gtfsDelayMs: 10 });

    await Promise.all([
      plan(planner, undefined, {
        ...input,
        destination: { ...input.destination, id: 'destination-one' },
      }),
      plan(planner, undefined, {
        ...input,
        destination: { ...input.destination, id: 'destination-two' },
      }),
    ]);

    expect(gtfsConcurrency.max).toBe(1);
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

  test('prefers a non-peak alternative inside the three-minute band', () => {
    const peak = { ...modalJourney('metro', 1_800), peak: {
      ratio: 1,
      level: 'peak' as const,
      stationName: 'Châtelet',
      label: 'heure la plus chargée',
    } };
    const calm = modalJourney('rer', 1_920);

    const ranked = rankPreferredJourney([peak, calm], []);

    expect(ranked.map((journey) => journey.id)).toEqual(['rer', 'metro']);
    expect(ranked[0]?.qualifier).toBe('recommended');
    expect(ranked[1]?.qualifier).toBe('rapid');
  });

  test('never moves a peak journey behind a route that is more than three minutes faster', () => {
    const fastPeak = { ...modalJourney('metro', 1_200), peak: {
      ratio: 1,
      level: 'peak' as const,
      stationName: 'Châtelet',
      label: 'heure la plus chargée',
    } };
    const calm = modalJourney('rer', 1_560);

    expect(rankPreferredJourney([fastPeak, calm], []).map((journey) => journey.id)).toEqual(['metro', 'rer']);
  });

  test('reported crowding participates in alternative ranking', () => {
    const crowded = { ...modalJourney('metro', 1_800), reportedCrowding: {
      level: 'high' as const,
      stationName: 'Châtelet',
      label: 'Affluence forte signalée',
      reporterCount: 2,
      expiresAt: '2026-08-12T11:00:00Z',
    } };
    const calm = modalJourney('rer', 1_920);
    expect(rankPreferredJourney([crowded, calm], []).map((journey) => journey.id))
      .toEqual(['rer', 'metro']);
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

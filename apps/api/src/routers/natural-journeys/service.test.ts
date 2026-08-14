import { expect, test } from 'bun:test';
import type {
  Journey,
  JourneysResponse,
  NaturalJourneyResponse,
  RouteIntent,
  SearchResult,
} from '@via/contract';

import { createNaturalJourneyService } from './service';

const now = new Date('2026-08-14T08:00:00Z');
const station = (id: string, name: string): SearchResult => ({
  kind: 'station',
  id,
  name,
  coordinate: { latitude: 48.86, longitude: 2.35 },
  routes: [],
});
const journey: Journey = {
  id: 'j1',
  qualifier: 'recommended',
  durationSeconds: 900,
  walkingDurationSeconds: 120,
  transferCount: 0,
  departureAt: '2026-08-14T08:30:00Z',
  arrivalAt: '2026-08-14T08:45:00Z',
  status: 'normal',
  warnings: [],
  sections: [
    {
      type: 'transit',
      durationSeconds: 900,
      from: { name: 'Châtelet', coordinate: { latitude: 48.86, longitude: 2.35 } },
      to: { name: 'Gare du Nord', coordinate: { latitude: 48.88, longitude: 2.35 } },
      geometry: [],
      route: { id: 'rer-b', shortName: 'B', longName: 'RER B', mode: 'rer', color: '#000', textColor: '#fff' },
      stops: [],
    },
  ],
};

test('interprets without sharing coordinates and plans only verified places', async () => {
  let interpretedPhrase = '';
  const service = serviceWith({
    intent: intent({
      origin: { kind: 'place', query: 'Châtelet' },
      destinationQuery: 'Gare du Nord',
      requestedAt: '2026-08-14T10:00:00+02:00',
      datetimeRepresents: 'arrival',
    }),
    onInterpret: (phrase) => { interpretedPhrase = phrase; },
  });
  const response = await service.submit(
    {
      action: 'submit',
      query: 'depuis Châtelet je veux être gare du nord à 10h',
      currentLocation: { latitude: 1, longitude: 2 },
    },
    { identity: 'device-a' }
  );

  expect(interpretedPhrase).toBe('depuis Châtelet je veux être gare du nord à 10h');
  expect(response.status).toBe('ready');
  if (response.status === 'ready') {
    expect(response.interpretation.destination.name).toBe('Gare du Nord');
    expect(response.interpretation.datetimeRepresents).toBe('arrival');
    expect(response.answerSource).toBe('deterministic');
  }
});

test('groups origin, destination and time ambiguity in one clarification', async () => {
  const service = serviceWith({
    intent: intent({
      origin: { kind: 'place', query: 'Gare' },
      destinationQuery: 'Centre',
      datetimeRepresents: 'ambiguous',
    }),
    ambiguousQueries: new Set(['Gare', 'Centre']),
  });
  const response = await service.submit(
    { action: 'submit', query: 'de la gare au centre à 9h' },
    { identity: 'device-b' }
  );

  expect(response.status).toBe('needs_clarification');
  if (response.status === 'needs_clarification') {
    expect(response.fields.map(({ target }) => target)).toEqual(['origin', 'destination', 'time']);
  }
});

test('returns the fixed unsupported copy', async () => {
  const service = serviceWith({ intent: intent({ scope: 'unsupported' }) });
  const response = await service.submit(
    { action: 'submit', query: 'donne-moi la météo' },
    { identity: 'device-c' }
  );
  expect(response).toMatchObject({
    status: 'unsupported',
    message: 'Via peut t’aider à préparer un trajet en Île-de-France',
  });
});

test('rejects a requested date beyond the imported service horizon', async () => {
  const service = serviceWith({
    intent: intent({ requestedAt: '2027-01-02T10:00:00+01:00' }),
    latestDate: '2026-12-31',
  });
  const response = await service.submit(
    {
      action: 'submit',
      query: 'Gare du Nord le 2 janvier 2027',
      currentLocation: { latitude: 48.86, longitude: 2.35 },
    },
    { identity: 'device-d' }
  );
  expect(response).toMatchObject({ status: 'unavailable', reason: 'date_out_of_range' });
});

test('announces the earliest departure-now alternative when an arrival deadline is impossible', async () => {
  const service = serviceWith({
    intent: intent({ datetimeRepresents: 'arrival' }),
    journeyResponses: [
      { status: 'no-route', source: 'gtfs-theoretical', generatedAt: now.toISOString(), journeys: [] },
      { status: 'ready', source: 'gtfs-theoretical', generatedAt: now.toISOString(), journeys: [journey] },
    ],
  });
  const response = await service.submit(
    {
      action: 'submit',
      query: 'Gare du Nord avant 10h',
      currentLocation: { latitude: 48.86, longitude: 2.35 },
    },
    { identity: 'device-e' }
  );
  expect(response.status).toBe('ready');
  if (response.status === 'ready') {
    expect(response.preferenceNotice).toContain('Aucun trajet n’arrive à l’heure demandée');
  }
});

function serviceWith(options: {
  intent: RouteIntent;
  ambiguousQueries?: Set<string>;
  onInterpret?: (phrase: string) => void;
  latestDate?: string;
  journeyResponses?: JourneysResponse[];
}) {
  const counts = new Map<string, number>();
  let journeyCall = 0;
  return createNaturalJourneyService({
    redis: {
      get: async () => null,
      set: async () => 'OK',
      incr: async (key) => {
        const count = (counts.get(key) ?? 0) + 1;
        counts.set(key, count);
        return count;
      },
      expire: async () => 1,
    },
    model: {
      interpret: async (phrase) => {
        options.onInterpret?.(phrase);
        return {
          intent: options.intent,
          metrics: {
            model: 'fake',
            promptVersion: 'test',
            inputTokens: 1,
            outputTokens: 1,
            costUsd: 0,
          },
        };
      },
      writeAnswer: async () => ({ answer: null }),
    },
    places: {
      resolve: async (query) =>
        options.ambiguousQueries?.has(query)
          ? { status: 'ambiguous', candidates: [station(`${query}-1`, query), station(`${query}-2`, query)] }
          : { status: 'resolved', result: station(query, query) },
    },
    journeys: {
      plan: async () =>
        options.journeyResponses?.[journeyCall++] ?? {
          status: 'ready',
          source: 'idfm-realtime',
          generatedAt: now.toISOString(),
          journeys: [journey],
        },
    },
    horizon: { latestDate: async () => options.latestDate ?? '2026-12-31' },
    clock: { now: () => now },
    config: {
      enabled: true,
      rolloutPercent: 100,
      personalLimit: 20,
      personalWindowSeconds: 900,
      breakerFailures: 5,
      breakerCooldownSeconds: 60,
    },
  });
}

function intent(overrides: Partial<RouteIntent> = {}): RouteIntent {
  return {
    scope: 'journey',
    origin: { kind: 'current_location' },
    destinationQuery: 'Gare du Nord',
    requestedAt: '2026-08-14T10:00:00+02:00',
    datetimeRepresents: 'departure',
    requiredModes: [],
    excludedModes: [],
    preferredModes: [],
    ...overrides,
  };
}

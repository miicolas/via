import { expect, test } from 'bun:test';
import type { JourneyInput } from '@via/contract';

import { createIdfmJourneyPlanner, journeyUrl } from './client';

test('sends exact arrival time and modal constraints to IDFM', () => {
  const input: JourneyInput = {
    origin: { latitude: 48.8566, longitude: 2.3522 },
    destination: {
      kind: 'station',
      id: 'north',
      name: 'Gare du Nord',
      coordinate: { latitude: 48.8809, longitude: 2.3553 },
    },
    limit: 4,
    requestedAt: '2026-10-25T09:30:00+01:00',
    datetimeRepresents: 'arrival',
    requiredModes: ['bus', 'tram', 'transilien'],
    excludedModes: ['rer', 'metro'],
  };
  const url = journeyUrl('https://example.test/journeys', input, new Date(input.requestedAt!));

  expect(url.searchParams.get('datetime')).toBe('20261025T093000');
  expect(url.searchParams.get('datetime_represents')).toBe('arrival');
  expect(url.searchParams.get('disable_geojson')).toBe('false');
  expect(url.searchParams.getAll('allowed_id[]')).toEqual([
    'physical_mode:Bus',
    'physical_mode:Tramway',
    'physical_mode:LocalTrain',
  ]);
  expect(url.searchParams.getAll('forbidden_uris[]')).toEqual([
    'physical_mode:RapidTransit',
    'physical_mode:Metro',
  ]);
  // The walk and the ride are on-device work: a direct path here would eat
  // journey slots and filter out every transit journey slower than it.
  expect(url.searchParams.get('direct_path')).toBe('none');
  expect(url.searchParams.getAll('direct_path_mode[]')).toEqual([]);
});

test('pins a PMR station journey to the selected stop areas', () => {
  const input: JourneyInput = {
    origin: { latitude: 48.8566, longitude: 2.3522 },
    originStationId: 'IDFM:71410',
    destination: {
      kind: 'station',
      id: 'IDFM:71264',
      name: 'Châtelet',
      coordinate: { latitude: 48.8584, longitude: 2.347 },
    },
    limit: 4,
    requiresAccessibleStations: true,
  };

  const url = journeyUrl('https://example.test/journeys', input, new Date('2026-08-20T08:00:00Z'));

  expect(url.searchParams.get('from')).toBe('stop_area:IDFM:71410');
  expect(url.searchParams.get('to')).toBe('stop_area:IDFM:71264');
  expect(url.searchParams.get('wheelchair')).toBe('true');
  expect(url.searchParams.get('direct_path')).toBe('none');
});

test('preserves a Navitia-qualified stop point when pinning departure choices', () => {
  const input: JourneyInput = {
    origin: { latitude: 48.854, longitude: 2.35 },
    originStationId: 'stop_point:IDFM:22149',
    destination: {
      kind: 'station',
      id: 'IDFM:71264',
      name: 'Châtelet',
      coordinate: { latitude: 48.8584, longitude: 2.347 },
    },
    limit: 1,
  };

  const url = journeyUrl(
    'https://example.test/journeys',
    input,
    new Date('2026-08-23T12:00:00+02:00')
  );

  expect(url.searchParams.get('from')).toBe('stop_point:IDFM:22149');
});

/**
 * PRIM's load balancer was measured answering 200 with an empty body for the
 * same request that carried four itineraries on the next call. The planner
 * asks a second time before believing "no line connects these two points".
 */

const navitiaBody = {
  journeys: [
    {
      departure_date_time: '20260827T142000',
      arrival_date_time: '20260827T152000',
      duration: 3_600,
      sections: [
        {
          type: 'public_transport',
          duration: 3_600,
          departure_date_time: '20260827T142000',
          arrival_date_time: '20260827T152000',
          from: { name: 'Chatou', coord: { lon: 2.157, lat: 48.898 } },
          to: { name: 'Auber', coord: { lon: 2.329, lat: 48.872 } },
          display_informations: { code: 'A', name: 'RER A', commercial_mode: 'RER' },
        },
      ],
    },
  ],
};

function plannerAnswering(bodies: unknown[]) {
  const requested: URL[] = [];
  const connectionHeaders: Array<string | null> = [];
  const planner = createIdfmJourneyPlanner({
    apiKey: 'test',
    url: 'https://prim.test/journeys',
    loadShapes: async () => [],
    fetcher: async (url, init) => {
      requested.push(url);
      connectionHeaders.push(
        (init?.headers as Record<string, string> | undefined)?.Connection ?? null
      );
      const body = bodies[Math.min(requested.length, bodies.length) - 1];
      return new Response(JSON.stringify(body), { status: 200 });
    },
  });
  return { planner, requested, connectionHeaders };
}

const suburbanInput: JourneyInput = {
  origin: { latitude: 48.949315, longitude: 2.034841 },
  destination: {
    kind: 'address',
    id: '75102_9893_00015',
    name: '15 Rue Vivienne',
    coordinate: { latitude: 48.868267, longitude: 2.33964 },
  },
  limit: 4,
};

test('asks PRIM a second time when the first answer is empty', async () => {
  const { planner, requested } = plannerAnswering([{}, navitiaBody]);

  const response = await planner.plan(suburbanInput, new Date('2026-08-27T12:15:00Z'));

  expect(requested).toHaveLength(2);
  expect(response.outcome).toBe('answered');
  expect(response.outcome === 'answered' && response.journeys).toHaveLength(1);
});

/**
 * Keep-alive is what makes the empty answer persist: the pool sends every
 * request back to the backend that answered the first one. Retrying down the
 * same connection would only ask the broken backend again.
 */
test('the retry leaves the connection pool so the load balancer draws again', async () => {
  const { planner, connectionHeaders } = plannerAnswering([{}, navitiaBody]);

  await planner.plan(suburbanInput, new Date('2026-08-27T12:15:00Z'));

  expect(connectionHeaders).toEqual([null, 'close']);
});

test('a healthy answer costs a single call', async () => {
  const { planner, requested } = plannerAnswering([navitiaBody]);

  const response = await planner.plan(suburbanInput, new Date('2026-08-27T12:15:00Z'));

  expect(requested).toHaveLength(1);
  expect(response.outcome).toBe('answered');
});

test('a reproducible dead end stays a dead end after exactly one retry', async () => {
  const { planner, requested } = plannerAnswering([{}, {}]);

  const response = await planner.plan(suburbanInput, new Date('2026-08-27T12:15:00Z'));

  expect(requested).toHaveLength(2);
  expect(response).toEqual({ outcome: 'empty', attempts: 2 });
});

test('the retry can be turned off at construction, and the answer says one attempt', async () => {
  const requested: URL[] = [];
  const planner = createIdfmJourneyPlanner({
    apiKey: 'test',
    url: 'https://prim.test/journeys',
    loadShapes: async () => [],
    retryEmptyAnswerOnFreshConnection: false,
    fetcher: async (url) => {
      requested.push(url);
      return new Response(JSON.stringify({}), { status: 200 });
    },
  });

  const response = await planner.plan(suburbanInput, new Date('2026-08-27T12:15:00Z'));

  expect(requested).toHaveLength(1);
  expect(response).toEqual({ outcome: 'empty', attempts: 1 });
});

/**
 * A refusal claims nothing about the route, so it is named — not retried:
 * the fresh-connection retry exists for the empty *answer*, and the caller
 * decides what a timeout or a 503 costs.
 */
test('a failed round-trip is a named refusal, not an empty answer', async () => {
  const requested: URL[] = [];
  const planner = createIdfmJourneyPlanner({
    apiKey: 'test',
    url: 'https://prim.test/journeys',
    loadShapes: async () => [],
    fetcher: async (url) => {
      requested.push(url);
      return new Response('rate limited', { status: 429 });
    },
  });

  const response = await planner.plan(suburbanInput, new Date('2026-08-27T12:15:00Z'));

  expect(requested).toHaveLength(1);
  expect(response).toEqual({ outcome: 'refused', cause: 'http_error' });
});

test('a body that is not JSON is refused with its own cause', async () => {
  const planner = createIdfmJourneyPlanner({
    apiKey: 'test',
    url: 'https://prim.test/journeys',
    loadShapes: async () => [],
    fetcher: async () => new Response('<html>maintenance</html>', { status: 200 }),
  });

  const response = await planner.plan(suburbanInput, new Date('2026-08-27T12:15:00Z'));

  expect(response).toEqual({ outcome: 'refused', cause: 'invalid_json' });
});

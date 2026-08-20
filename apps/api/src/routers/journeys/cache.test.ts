import { expect, test } from 'bun:test';

import { fakeRedis } from '../departures/__fixtures__/fake-redis';
import { journeyCacheKey, valueThroughCache } from './cache';

test('concurrent journey misses share one upstream calculation', async () => {
  const { client } = fakeRedis();
  let loads = 0;
  const load = async () => {
    loads += 1;
    await new Promise((resolve) => setTimeout(resolve, 120));
    return { value: { status: 'ready' }, ttlSeconds: 30 };
  };

  const [first, second] = await Promise.all([
    valueThroughCache(client, 'same-trip', load),
    valueThroughCache(client, 'same-trip', load),
  ]);

  expect(loads).toBe(1);
  expect(first).toEqual({ status: 'ready' });
  expect(second).toEqual(first);
});

test('time direction and modal policies partition the journey cache', () => {
  const base = {
    origin: { latitude: 48.8566, longitude: 2.3522 },
    destination: {
      id: 'north',
      coordinate: { latitude: 48.8809, longitude: 2.3553 },
    },
    limit: 4,
    requestedAt: new Date('2026-08-14T08:00:00Z'),
  };
  const departure = journeyCacheKey({ ...base, datetimeRepresents: 'departure' });
  const arrival = journeyCacheKey({ ...base, datetimeRepresents: 'arrival' });
  const preferredBus = journeyCacheKey({ ...base, preferredModes: ['bus'] });
  const requiredBus = journeyCacheKey({ ...base, requiredModes: ['bus'] });
  const accessible = journeyCacheKey({ ...base, requiresAccessibleStations: true });
  const selectedOrigin = journeyCacheKey({ ...base, originStationId: 'IDFM:71410' });

  expect(new Set([departure, arrival, preferredBus, requiredBus, accessible, selectedOrigin]).size).toBe(6);
});

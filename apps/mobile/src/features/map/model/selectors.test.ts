import { describe, expect, test } from 'bun:test';
import type { NetworkRoute, NetworkStation } from '@via/contract';

import { nearestStation } from '@/features/map/model/nearest-station';
import { routesForStation } from '@/features/map/model/routes-for-station';

const stations: NetworkStation[] = [
  {
    id: 'republique',
    name: 'République',
    positions: { 'line-5': { latitude: 48.8675, longitude: 2.3638 } },
  },
  {
    id: 'nation',
    name: 'Nation',
    positions: {
      'line-1': { latitude: 48.8484, longitude: 2.3958 },
      'line-2': { latitude: 48.8482, longitude: 2.396 },
    },
  },
  {
    id: 'assemblee',
    name: 'Assemblée Nationale',
    positions: { 'line-12': { latitude: 48.8608, longitude: 2.3209 } },
  },
];

const routes = ['line-1', 'line-2', 'line-5'].map(
  (id, index): NetworkRoute => ({
    id,
    shortName: String(index + 1),
    longName: String(index + 1),
    color: '#000000',
    textColor: '#FFFFFF',
    mode: 'metro',
    destinations: [],
    segments: [],
  })
);

describe('home map selectors', () => {
  test('finds the closest station using real coordinates', () => {
    const result = nearestStation(stations, { latitude: 48.8674, longitude: 2.3639 });

    expect(result?.station.id).toBe('republique');
    expect(result?.distanceMeters).toBeLessThan(20);
  });

  test('returns only the lines served by the station', () => {
    expect(routesForStation(routes, stations[1]).map(({ id }) => id)).toEqual([
      'line-1',
      'line-2',
    ]);
  });
});

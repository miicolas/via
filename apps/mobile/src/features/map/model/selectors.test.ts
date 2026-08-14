import { describe, expect, test } from 'bun:test';
import type { NetworkStation } from '@via/contract';

import { nearestStation } from '@/features/map/model/nearest-station';

const stations: NetworkStation[] = [
  {
    id: 'republique',
    name: 'République',
    coordinate: { latitude: 48.8675, longitude: 2.3638 },
    routeIds: ['line-5'],
  },
  {
    id: 'nation',
    name: 'Nation',
    coordinate: { latitude: 48.8484, longitude: 2.3958 },
    routeIds: ['line-1', 'line-2'],
  },
  {
    id: 'assemblee',
    name: 'Assemblée Nationale',
    coordinate: { latitude: 48.8608, longitude: 2.3209 },
    routeIds: ['line-12'],
  },
];

describe('home map selectors', () => {
  test('finds the closest station using real coordinates', () => {
    const result = nearestStation(stations, { latitude: 48.8674, longitude: 2.3639 });

    expect(result?.station.id).toBe('republique');
    expect(result?.distanceMeters).toBeLessThan(20);
  });
});

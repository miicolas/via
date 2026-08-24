import { describe, expect, test } from 'bun:test';
import type { BikeStation } from '@via/contract';

import { selectBikeStationsInArea, selectMatchingBikeStations } from './select';

const stations: BikeStation[] = [
  {
    id: '1',
    name: 'Hôtel de Ville',
    coordinate: { latitude: 48.8569, longitude: 2.3522 },
    capacity: 35,
    availability: {
      mechanicalBikes: 4,
      electricBikes: 3,
      docks: 28,
      isInstalled: true,
      isRenting: true,
      isReturning: true,
    },
  },
  {
    id: '2',
    name: 'Hôpital Saint-Louis',
    coordinate: { latitude: 48.8738, longitude: 2.3682 },
    capacity: 20,
  },
];

describe('Vélib station selection', () => {
  // The distance is stamped by `mergeSearchResults`, which every source goes
  // through — `merge.test.ts` owns that assertion.
  test('search is accent-insensitive and returns a routable address result', () => {
    const [result] = selectMatchingBikeStations(
      stations,
      'hotel',
      10,
      { latitude: 48.8566, longitude: 2.3522 }
    );

    expect(result?.kind).toBe('bikeStation');
    expect(result?.id).toBe('1');
    expect(result?.capacity).toBe(35);
    expect(result?.availability?.electricBikes).toBe(3);
  });

  test('map selection stays inside the requested tile', () => {
    expect(selectBikeStationsInArea(stations, {
      minLatitude: 48.85,
      maxLatitude: 48.86,
      minLongitude: 2.35,
      maxLongitude: 2.36,
    }).map((station) => station.id)).toEqual(['1']);
  });
});

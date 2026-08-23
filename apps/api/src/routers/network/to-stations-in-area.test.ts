import { describe, expect, test } from 'bun:test';
import { stationsInAreaSchema } from '@via/contract';

import type { StationInAreaRow } from './queries';
import { toStationsInArea } from './to-stations-in-area';

const BUS_38 = {
  id: 'IDFM:C01099',
  shortName: '38',
  routeType: 3,
  color: 'A66013',
  textColor: 'FFFFFF',
};
const BUS_47 = {
  id: 'IDFM:C01133',
  shortName: '47',
  routeType: 3,
  color: '89C7D6',
  textColor: '000000',
};

const rows: StationInAreaRow[] = [
  {
    id: 'IDFM:10001',
    name: 'Gare de l’Est',
    // The driver can hand geometry accessors back as strings.
    longitude: '2.3590' as unknown as number,
    latitude: '48.8765' as unknown as number,
    accessibilityCondition: 'autonomous',
    accessibilityDetail: null,
    toiletStopId: 'IDFM:10001',
    toiletDetail: 'Accès gratuit · Accessible PMR',
    routes: [BUS_38, BUS_47],
  },
  {
    id: 'IDFM:10002',
    name: 'Magenta',
    longitude: 2.3577 as number,
    latitude: 48.8778 as number,
    accessibilityCondition: null,
    accessibilityDetail: null,
    toiletStopId: null,
    toiletDetail: null,
    routes: [BUS_38],
  },
];

describe('toStationsInArea', () => {
  test('stations carry their coordinate and route ids, numbers coerced', () => {
    const { stations } = toStationsInArea(rows);

    expect(stations[0]).toEqual({
      id: 'IDFM:10001',
      name: 'Gare de l’Est',
      coordinate: { latitude: 48.8765, longitude: 2.359 },
      routeIds: ['IDFM:C01099', 'IDFM:C01133'],
      accessibility: {
        condition: 'autonomous',
        label: 'En autonomie',
      },
      toilets: {
        label: 'Sanitaires disponibles',
        detail: 'Accès gratuit · Accessible PMR',
      },
    });
  });

  test('badges land once, deduplicated across every station of the area', () => {
    const { routes } = toStationsInArea(rows);

    expect(routes.map((route) => route.id).sort()).toEqual(['IDFM:C01099', 'IDFM:C01133']);
    expect(routes.find((route) => route.id === BUS_38.id)).toEqual({
      id: 'IDFM:C01099',
      shortName: '38',
      mode: 'bus',
      color: '#A66013',
      textColor: '#FFFFFF',
    });
  });

  test('matches the wire contract', () => {
    expect(() => stationsInAreaSchema.parse(toStationsInArea(rows))).not.toThrow();
  });

  test('an empty area yields empty collections', () => {
    expect(toStationsInArea([])).toEqual({ stations: [], routes: [] });
  });
});

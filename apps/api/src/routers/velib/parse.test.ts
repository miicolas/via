import { describe, expect, test } from 'bun:test';
import { bikeStationSchema } from '@via/contract';

import { parseVelibStations } from './parse';

const information = {
  data: {
    stations: [
      {
        station_id: 123,
        stationCode: '04001',
        name: 'Hôtel de Ville',
        lat: 48.8569,
        lon: 2.3522,
        capacity: 35,
      },
      { station_id: 'broken', name: '', lat: 200, lon: 2.3, capacity: -1 },
    ],
  },
};

const status = {
  data: {
    stations: [
      {
        station_id: '123',
        num_bikes_available_types: [{ mechanical: 4 }, { ebike: 3 }],
        num_docks_available: 28,
        is_installed: 1,
        is_renting: 1,
        is_returning: 0,
        last_reported: 1_787_563_934,
      },
    ],
  },
};

describe('parseVelibStations', () => {
  test('joins numeric and string ids into the Via bike-station contract', () => {
    const stations = parseVelibStations(information, status);

    expect(stations).toHaveLength(1);
    expect(stations?.[0]).toEqual({
      id: '123',
      stationCode: '04001',
      name: 'Hôtel de Ville',
      coordinate: { latitude: 48.8569, longitude: 2.3522 },
      capacity: 35,
      availability: {
        mechanicalBikes: 4,
        electricBikes: 3,
        docks: 28,
        isInstalled: true,
        isRenting: true,
        isReturning: false,
        lastReportedAt: '2026-08-24T09:32:14.000Z',
      },
    });
    expect(() => bikeStationSchema.parse(stations?.[0])).not.toThrow();
  });

  test('keeps information when a station has no live status', () => {
    const stations = parseVelibStations(information, { data: { stations: [] } });

    expect(stations?.[0]).not.toHaveProperty('availability');
  });

  test('rejects an invalid envelope without throwing', () => {
    expect(parseVelibStations({}, status)).toBeNull();
  });
});

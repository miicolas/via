import { expect, test } from 'bun:test';

import { selectInArea } from '../../geo/area';

import {
  findManifestFeed,
  parseDottVehicles,
  parseLimeVehicles,
  parseManifestFeeds,
  parseVelibSharedMobility,
  parseYegoVehicles,
} from './parse';

const now = new Date('2026-08-26T10:00:00.000Z');
const freshTimestamp = Math.floor(now.getTime() / 1_000) - 10;

function feed(data: Record<string, unknown>, ttl = 60, lastUpdated = freshTimestamp) {
  return {
    last_updated: lastUpdated,
    ttl,
    version: '2.3',
    data,
  };
}

test('Dott maps bicycles and scooters and excludes non-rentable vehicles', () => {
  const result = parseDottVehicles(
    feed({
      bikes: [
        {
          bike_id: 'bike',
          lat: 48.85,
          lon: 2.35,
          vehicle_type_id: 'bike-type',
          is_reserved: false,
          is_disabled: false,
          current_fuel_percent: 0.64,
          current_range_meters: 12_345,
          last_reported: freshTimestamp,
          rental_uris: { ios: 'dott://bike', web: 'https://dott.example/bike' },
        },
        {
          bike_id: 'scooter',
          lat: 48.851,
          lon: 2.351,
          vehicle_type_id: 'scooter-type',
          is_reserved: false,
          is_disabled: false,
        },
        {
          bike_id: 'reserved',
          lat: 48.852,
          lon: 2.352,
          vehicle_type_id: 'bike-type',
          is_reserved: true,
          is_disabled: false,
        },
        {
          bike_id: 'disabled',
          lat: 48.853,
          lon: 2.353,
          vehicle_type_id: 'bike-type',
          is_reserved: false,
          is_disabled: true,
        },
      ],
    }),
    feed({
      vehicle_types: [
        { vehicle_type_id: 'bike-type', form_factor: 'bicycle', name: 'Vélo électrique' },
        { vehicle_type_id: 'scooter-type', form_factor: 'scooter' },
      ],
    }, 86400),
    'paris',
    now
  );

  expect(result?.items).toHaveLength(2);
  expect(result?.items[0]).toMatchObject({
    id: 'dott:paris:bike',
    provider: 'dott',
    mode: 'bicycle',
    batteryPercent: 64,
    rangeMeters: 12_345,
    rentalUrl: 'dott://bike',
  });
  expect(result?.items[1]).toMatchObject({
    id: 'dott:paris:scooter',
    mode: 'scooter',
  });
});

test('Dott annotates a vehicle inside a current restricted geofence', () => {
  const result = parseDottVehicles(
    feed({
      bikes: [{
        bike_id: 'restricted-bike',
        lat: 48.8505,
        lon: 2.3505,
        vehicle_type_id: 'dott_bicycle',
        is_reserved: false,
        is_disabled: false,
      }],
    }),
    null,
    'paris',
    now,
    feed({
      geofencing_zones: {
        type: 'FeatureCollection',
        features: [{
          type: 'Feature',
          properties: {
            rules: [{ ride_allowed: false, vehicle_type_id: ['dott_bicycle'] }],
          },
          geometry: {
            type: 'Polygon',
            coordinates: [[
              [2.35, 48.85],
              [2.351, 48.85],
              [2.351, 48.851],
              [2.35, 48.851],
              [2.35, 48.85],
            ]],
          },
        }],
      },
    })
  );

  expect(result?.items[0]).toMatchObject({
    id: 'dott:paris:restricted-bike',
    restriction: 'no-ride',
  });
});

test('a geofence without a reuse window annotates the fleet without revoking its TTL', () => {
  const result = parseDottVehicles(
    feed({
      bikes: [{
        bike_id: 'fresh-bike',
        lat: 48.85,
        lon: 2.35,
        vehicle_type_id: 'dott_bicycle',
        is_reserved: false,
        is_disabled: false,
      }],
    }),
    null,
    'paris',
    now,
    feed({
      geofencing_zones: {
        type: 'FeatureCollection',
        features: [],
      },
    }, 0)
  );

  expect(result?.items).toHaveLength(1);
  expect(result?.expiresAt).toBe(new Date((freshTimestamp + 60) * 1_000).toISOString());
  // The zones are a regulatory overlay, not the thing that ages: refusing to
  // reuse the fleet because of them refetched every feed on every request.
  expect(result?.cacheable).toBe(true);
});

test('Lime is normalized to bicycles while keeping optional feed fields', () => {
  const result = parseLimeVehicles(
    feed({
      bikes: [{
        bike_id: 'lime-bike',
        lat: 48.85,
        lon: 2.35,
        is_reserved: false,
        is_disabled: false,
        vehicle_type: 'e-bike',
        current_range_meters: 9_000,
      }],
    }),
    null,
    now
  );

  expect(result?.items).toEqual([expect.objectContaining({
    id: 'lime:lime-bike',
    provider: 'lime',
    mode: 'bicycle',
    vehicleType: 'e-bike',
    rangeMeters: 9_000,
    operatorUrl: 'https://li.me/',
  })]);
});

test('Lime keeps a rentable bicycle in a suburban viewport', () => {
  const result = parseLimeVehicles(
    feed({
      bikes: [{
        bike_id: 'lime-creteil',
        lat: 48.7904,
        lon: 2.4556,
        is_reserved: false,
        is_disabled: false,
      }],
    }),
    null,
    now
  );

  const items = selectInArea(result?.items ?? [], {
    minLatitude: 48.78,
    maxLatitude: 48.80,
    minLongitude: 2.44,
    maxLongitude: 2.47,
  });

  expect(items.map((item) => item.id)).toEqual(['lime:lime-creteil']);
});

test('YEGO is normalized to scooters regardless of malformed form factors', () => {
  const result = parseYegoVehicles(
    feed({
      bikes: [{
        bike_id: 'yego-scooter',
        lat: 48.85,
        lon: 2.35,
        is_reserved: false,
        is_disabled: false,
        vehicle_type_id: 'yego-kick',
      }],
    }),
    feed({
      vehicle_types: [{
        vehicle_type_id: 'yego-kick',
        form_factor: 'bicycle',
        name: 'Trottinette électrique',
      }],
    }),
    now
  );

  expect(result?.items).toEqual([expect.objectContaining({
    id: 'yego:yego-scooter',
    provider: 'yego',
    mode: 'scooter',
    vehicleType: 'Trottinette électrique',
  })]);
});

test('expired feeds are masked while ttl zero is not reused by the cache', () => {
  const expired = parseLimeVehicles(
    feed({
      bikes: [{
        bike_id: 'old',
        lat: 48.85,
        lon: 2.35,
        is_reserved: false,
        is_disabled: false,
      }],
    }, 60, freshTimestamp - 60),
    null,
    now
  );
  const noReuseWindow = parseLimeVehicles(
    feed({
      bikes: [{
        bike_id: 'fresh-response',
        lat: 48.85,
        lon: 2.35,
        is_reserved: false,
        is_disabled: false,
      }],
    }, 0, freshTimestamp - 86_400),
    null,
    now
  );

  expect(expired).toBeNull();
  expect(noReuseWindow?.items[0].id).toBe('lime:fresh-response');
  expect(noReuseWindow?.expiresAt).toBeUndefined();
});

test('Vélib stations keep their mechanical, electric and dock inventory', () => {
  const result = parseVelibSharedMobility(
    {
      lastUpdatedOther: freshTimestamp,
      ttl: 60,
      data: {
        stations: [{
          station_id: 42,
          stationCode: '04001',
          name: 'Hôtel de Ville',
          lat: 48.8569,
          lon: 2.3522,
          capacity: 35,
        }],
      },
    },
    {
      lastUpdatedOther: freshTimestamp,
      ttl: 60,
      data: {
        stations: [{
          station_id: 42,
          num_bikes_available_types: [{ mechanical: 4 }, { ebike: 3 }],
          num_docks_available: 28,
          is_installed: 1,
          is_renting: 1,
          is_returning: 1,
          last_reported: freshTimestamp,
        }],
      },
    },
    now
  );

  expect(result?.items).toEqual([expect.objectContaining({
    kind: 'station',
    id: 'velib:42',
    provider: 'velib',
    capacity: 35,
    availability: expect.objectContaining({
      mechanicalBikes: 4,
      electricBikes: 3,
      docks: 28,
    }),
  })]);
});

test('manifest selection keeps Dott systems in the Île-de-France scope', () => {
  const feeds = parseManifestFeeds({
    data: {
      en: {
        feeds: [
          { name: 'free_bike_status', url: 'https://example.test/paris/free_bike_status.json' },
          { name: 'free_bike_status', url: 'https://example.test/lyon/free_bike_status.json' },
        ],
      },
    },
  });

  expect(findManifestFeed(feeds ?? [], 'free_bike_status', 'paris')?.url.pathname).toBe(
    '/paris/free_bike_status.json'
  );
  expect(findManifestFeed(feeds ?? [], 'free_bike_status', 'lyon')?.url.pathname).toBe(
    '/lyon/free_bike_status.json'
  );
});

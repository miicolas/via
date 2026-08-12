import { expect, test } from 'bun:test';

import type { ScheduledTrip } from './import-schedules';
import { addScheduledTrip } from './scheduled-trips';

test('every imported transit mode contributes its GTFS trips', () => {
  const importedRouteIds = new Set(['metro-1', 'rer-a', 'bus-91']);
  const trips = new Map<string, ScheduledTrip>();

  for (const routeId of importedRouteIds) {
    addScheduledTrip(trips, importedRouteIds, {
      trip_id: `trip-${routeId}`,
      route_id: routeId,
      direction_id: '0',
      shape_id: `shape-${routeId}`,
      trip_headsign: `Terminus ${routeId}`,
      service_id: `service-${routeId}`,
    });
  }

  expect([...trips.values()].map((trip) => trip.routeId)).toEqual([
    'metro-1',
    'rer-a',
    'bus-91',
  ]);
});

test('a trip outside the imported network is ignored', () => {
  const trips = new Map<string, ScheduledTrip>();

  const added = addScheduledTrip(trips, new Set(['metro-1']), {
    trip_id: 'trip-tram-1',
    route_id: 'tram-1',
  });

  expect(added).toBeUndefined();
  expect(trips.size).toBe(0);
});

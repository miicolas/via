import type { NetworkStation } from '@via/contract';
import { expect, test } from 'bun:test';

import { stationsInViewport } from './stations-in-viewport';

const viewport = {
  latitude: 48.8566,
  longitude: 2.3522,
  latitudeDelta: 0.01,
  longitudeDelta: 0.01,
};

function station(id: string, latitude: number, longitude: number): NetworkStation {
  return {
    id,
    name: id,
    coordinate: { latitude, longitude },
    routeIds: ['route'],
  };
}

test('keeps only stops in or just around the visible map', () => {
  const visible = station('visible-bus-stop', 48.857, 2.353);
  const justOutside = station('prefetched-edge-stop', 48.862, 2.352);
  const distant = station('distant-stop', 49, 3);

  expect(stationsInViewport([visible, justOutside, distant], viewport)).toEqual([
    visible,
    justOutside,
  ]);
});

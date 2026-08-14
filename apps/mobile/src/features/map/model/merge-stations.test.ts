import type { NetworkStation } from '@via/contract';
import { expect, test } from 'bun:test';

import { mergeStations } from './merge-stations';

const chatelet: NetworkStation = {
  id: 'chatelet',
  name: 'Châtelet',
  coordinate: { latitude: 48.8584, longitude: 2.3486 },
  routeIds: ['metro-1', 'metro-4'],
};

const busStop: NetworkStation = {
  id: 'bus-stop',
  name: 'Rivoli',
  coordinate: { latitude: 48.8556, longitude: 2.36 },
  routeIds: ['bus-38'],
};

test('area stations join the rail stations', () => {
  expect(mergeStations([chatelet], [busStop])).toEqual([chatelet, busStop]);
});

test('a station known to both keeps its rail anchor and gains the bus lines', () => {
  const areaTwin: NetworkStation = {
    ...chatelet,
    coordinate: { latitude: 48.859, longitude: 2.349 },
    routeIds: ['metro-1', 'bus-38'],
  };

  const [merged] = mergeStations([chatelet], [areaTwin]);

  expect(merged.coordinate).toEqual(chatelet.coordinate);
  expect(merged.routeIds).toEqual(['metro-1', 'metro-4', 'bus-38']);
});

test('with nothing loaded from tiles, the rail list passes through untouched', () => {
  const rail = [chatelet];

  expect(mergeStations(rail, [])).toBe(rail);
});

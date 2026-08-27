import { expect, test } from 'bun:test';

import { mergeAccessStops, STRUCTURING_ACCESS_STOPS } from './access-stops';

const busPoles = Array.from({ length: 8 }, (_, index) => ({
  id: `bus-${index}`,
  metres: 200 + index * 25,
}));
const station = { id: 'chatou-croissy', metres: 900 };

test('the walkable station survives a suburb full of nearer bus poles', () => {
  const access = mergeAccessStops(busPoles, [station]);

  expect(access.map((stop) => stop.id)).toContain(station.id);
  // The reserved slot adds to the access set; it never evicts a nearer stop.
  expect(access).toHaveLength(busPoles.length + 1);
});

test('a station already among the nearest stops is not listed twice', () => {
  const nearest = [station, ...busPoles];

  const access = mergeAccessStops(nearest, [station]);

  expect(access).toHaveLength(nearest.length);
  expect(access.map((stop) => stop.id)).toEqual(nearest.map((stop) => stop.id));
});

test('keeps both lists in their own distance order, nearest first', () => {
  const access = mergeAccessStops(busPoles.slice(0, 2), [station, { id: 'far', metres: 2_400 }]);

  expect(access.map((stop) => stop.id)).toEqual(['bus-0', 'bus-1', 'chatou-croissy', 'far']);
});

test('an empty network stays empty rather than inventing access', () => {
  expect(mergeAccessStops([], [])).toEqual([]);
});

test('reserves enough slots for a station with several stop points', () => {
  expect(STRUCTURING_ACCESS_STOPS).toBeGreaterThanOrEqual(2);
});

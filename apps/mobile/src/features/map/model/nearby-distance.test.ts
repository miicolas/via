import { expect, test } from 'bun:test';

import { isNearbyDistance } from './nearby-distance';

test('shows live departures at 499 m', () => {
  expect(isNearbyDistance(499)).toBe(true);
});

test('plans a journey at exactly 500 m', () => {
  expect(isNearbyDistance(500)).toBe(false);
});

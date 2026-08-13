import { expect, test } from 'bun:test';

import { formatDistance } from '@/lib/format-distance';

test('meters below a kilometer', () => {
  expect(formatDistance(190)).toBe('190 m');
  expect(formatDistance(190.4)).toBe('190 m');
  expect(formatDistance(999)).toBe('999 m');
});

test('kilometers with a decimal comma', () => {
  expect(formatDistance(1_400)).toBe('1,4 km');
  expect(formatDistance(1_346)).toBe('1,3 km');
  expect(formatDistance(22_821)).toBe('22,8 km');
});

test('a whole number of kilometers drops the comma', () => {
  expect(formatDistance(2_000)).toBe('2 km');
  expect(formatDistance(1_960)).toBe('2 km');
});

test('the meter-kilometer boundary rounds sanely', () => {
  expect(formatDistance(999.6)).toBe('1 km');
  expect(formatDistance(1_000)).toBe('1 km');
  expect(formatDistance(1_049)).toBe('1 km');
  expect(formatDistance(1_050)).toBe('1,1 km');
});

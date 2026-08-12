import { expect, test } from 'bun:test';

import { parseGtfsTime } from './gtfs-time';

test('a plain time converts to seconds since midnight', () => {
  expect(parseGtfsTime('06:05:30')).toBe(6 * 3600 + 5 * 60 + 30);
});

test('after-midnight hours stay on the service day', () => {
  expect(parseGtfsTime('25:12:00')).toBe(90_720);
});

test('garbage refuses loudly', () => {
  expect(() => parseGtfsTime('noon')).toThrow('Not a GTFS time');
  expect(() => parseGtfsTime('12:60:00')).toThrow('Not a GTFS time');
});

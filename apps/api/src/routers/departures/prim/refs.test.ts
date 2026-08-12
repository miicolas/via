import { expect, test } from 'bun:test';

import { routeIdOfLineRef, toMonitoringRef } from './refs';

test('a station id becomes a StopArea monitoring ref', () => {
  expect(toMonitoringRef('IDFM:71264')).toBe('STIF:StopArea:SP:71264:');
});

test('a line ref reads back as a route id', () => {
  expect(routeIdOfLineRef('STIF:Line::C01371:')).toBe('IDFM:C01371');
});

test('a non-line ref reads back as null', () => {
  expect(routeIdOfLineRef('STIF:StopArea:SP:71264:')).toBeNull();
  expect(routeIdOfLineRef('')).toBeNull();
});

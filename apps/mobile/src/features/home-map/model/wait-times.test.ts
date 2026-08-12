import { expect, test } from 'bun:test';

import { waitTimes } from './wait-times';

const now = new Date('2026-08-12T18:00:00+02:00');

const inMinutes = (minutes: number) =>
  new Date(now.getTime() + minutes * 60_000).toISOString();

test('the next departure floors to whole minutes, the rest becomes a label', () => {
  const wait = waitTimes([inMinutes(2.5), inMinutes(4.2), inMinutes(9.9)], now);

  expect(wait).toEqual({ primaryMinutes: 2, followingLabel: 'puis 4 et 9 min' });
});

test('a lone departure carries no following label', () => {
  expect(waitTimes([inMinutes(3)], now)).toEqual({ primaryMinutes: 3 });
});

test('a train at the platform shows zero, not a negative', () => {
  expect(waitTimes([inMinutes(-0.2)], now)?.primaryMinutes).toBe(0);
});

test('departures older than the boarding grace disappear', () => {
  const wait = waitTimes([inMinutes(-2), inMinutes(5)], now);

  expect(wait).toEqual({ primaryMinutes: 5 });
});

test('nothing upcoming yields nothing to show', () => {
  expect(waitTimes([], now)).toBeUndefined();
  expect(waitTimes([inMinutes(-10)], now)).toBeUndefined();
});

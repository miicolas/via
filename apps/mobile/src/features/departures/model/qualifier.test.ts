import { expect, test } from 'bun:test';

import { departureQualifier } from './qualifier';

test('a theoretical time never passes for live, following departures or not', () => {
  expect(departureQualifier('theoretical', { primaryMinutes: 3 })).toBe('horaires théoriques');
  expect(
    departureQualifier('theoretical', { primaryMinutes: 3, followingLabel: 'puis 4 et 9 min' })
  ).toBe('horaires théoriques');
});

test('live times spend the line on the departures that follow', () => {
  expect(
    departureQualifier('realtime', { primaryMinutes: 3, followingLabel: 'puis 4 et 9 min' })
  ).toBe('puis 4 et 9 min');
  expect(departureQualifier('realtime', { primaryMinutes: 3 })).toBe('temps réel');
});

test('no wait distinguishes a quiet line from a dead feed', () => {
  expect(departureQualifier('realtime')).toBe('aucun passage annoncé');
  expect(departureQualifier('unavailable')).toBe('temps réel indisponible');
});

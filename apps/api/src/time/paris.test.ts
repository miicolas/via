import { expect, test } from 'bun:test';

import { compactParisDateTime, formatParisTime, parisDay, previousDate, toInstant } from './paris';

test('late evening in Paris is still the same service day, not UTC yesterday', () => {
  // 22:50 UTC = 00:50 Paris the next day.
  expect(parisDay(new Date('2026-08-12T21:50:00Z'))).toEqual({
    date: '2026-08-12',
    seconds: 23 * 3600 + 50 * 60,
  });
});

test('past midnight in Paris rolls the date forward', () => {
  expect(parisDay(new Date('2026-08-12T22:30:00Z')).date).toBe('2026-08-13');
});

test('service-day seconds convert back to the right instant in summer time', () => {
  expect(toInstant('2026-08-12', 18 * 3600)).toBe('2026-08-12T16:00:00.000Z');
});

test('winter time shifts by one hour, not two', () => {
  expect(toInstant('2026-01-15', 18 * 3600)).toBe('2026-01-15T17:00:00.000Z');
});

test('an after-midnight departure lands on the following calendar day', () => {
  // "25:12" of the 12th is 01:12 Paris on the 13th → 23:12 UTC on the 12th.
  expect(toInstant('2026-08-12', 90_720)).toBe('2026-08-12T23:12:00.000Z');
});

test('the previous date crosses months', () => {
  expect(previousDate('2026-08-01')).toBe('2026-07-31');
});

test('times format on the Paris clock', () => {
  expect(formatParisTime('2026-08-12T16:05:00.000Z')).toBe('18 h 05');
  expect(formatParisTime('2026-08-12T16:05:00.000Z', 'h')).toBe('18h05');
});

test('compact datetimes use the Paris wall clock', () => {
  expect(compactParisDateTime(new Date('2026-08-12T21:50:30Z'))).toBe('20260812T235030');
});

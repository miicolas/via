import { expect, test } from 'bun:test';

import { parisDay, previousDate, toInstant } from './index';

test('Paris civil time keeps a late evening on the same service day', () => {
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
  expect(toInstant('2026-08-12', 90_720)).toBe('2026-08-12T23:12:00.000Z');
});

test('the previous date crosses months', () => {
  expect(previousDate('2026-08-01')).toBe('2026-07-31');
});

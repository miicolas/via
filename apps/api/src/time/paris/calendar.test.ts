import { expect, test } from 'bun:test';

import { frenchHolidays, parisDayType } from './index';

test('computes an early Easter and its three dependent holidays', () => {
  expect(frenchHolidays(2024)).toEqual(new Set([
    '2024-01-01',
    '2024-04-01',
    '2024-05-01',
    '2024-05-08',
    '2024-05-09',
    '2024-05-20',
    '2024-07-14',
    '2024-08-15',
    '2024-11-01',
    '2024-11-11',
    '2024-12-25',
  ]));
});

test('computes a late Easter in a leap year', () => {
  expect(frenchHolidays(2019).has('2019-04-22')).toBe(true);
  expect(frenchHolidays(2019).has('2019-05-30')).toBe(true);
  expect(frenchHolidays(2019).has('2019-06-10')).toBe(true);
  expect(frenchHolidays(2019).has('2019-02-29')).toBe(false);
});

test('includes the first of November and keeps a holiday on Saturday', () => {
  expect(frenchHolidays(2026).has('2026-11-01')).toBe(true);
  expect(parisDayType(new Date('2026-11-01T12:00:00Z'))).toBe('sunday');
  // 2026-05-01 is a Friday; 2026-08-15 is the Saturday holiday case.
  expect(parisDayType(new Date('2026-08-15T10:00:00Z'))).toBe('sunday');
});

test('uses the Paris date around UTC midnight', () => {
  // 22:01 UTC is 00:01 in Paris during summer time.
  expect(parisDayType(new Date('2026-09-04T21:59:00Z'))).toBe('weekday');
  expect(parisDayType(new Date('2026-09-04T22:01:00Z'))).toBe('saturday');
});

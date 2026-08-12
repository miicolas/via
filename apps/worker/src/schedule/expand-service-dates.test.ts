import { expect, test } from 'bun:test';

import { expandServiceDates, type CalendarRow } from './expand-service-dates';

const weekdaysOnly: CalendarRow = {
  serviceId: 'WK',
  weekdays: [true, true, true, true, true, false, false],
  startDate: '20260810', // a Monday
  endDate: '20260816', // the Sunday after
};

test('a weekly bitmap expands to its matching days only', () => {
  const dates = expandServiceDates([weekdaysOnly], []);

  expect(dates.map(({ date }) => date)).toEqual([
    '2026-08-10',
    '2026-08-11',
    '2026-08-12',
    '2026-08-13',
    '2026-08-14',
  ]);
});

test('exceptions add and remove single days', () => {
  const dates = expandServiceDates(
    [weekdaysOnly],
    [
      { serviceId: 'WK', date: '20260815', exceptionType: 1 },
      { serviceId: 'WK', date: '20260812', exceptionType: 2 },
    ]
  );

  const days = dates.map(({ date }) => date);
  expect(days).toContain('2026-08-15');
  expect(days).not.toContain('2026-08-12');
});

test('a service defined by exceptions alone needs no calendar row', () => {
  const dates = expandServiceDates(
    [],
    [{ serviceId: 'XMAS', date: '20261225', exceptionType: 1 }]
  );

  expect(dates).toEqual([{ serviceId: 'XMAS', date: '2026-12-25' }]);
});

test('bounds are inclusive on both ends', () => {
  const single: CalendarRow = {
    serviceId: 'ONE',
    weekdays: [true, true, true, true, true, true, true],
    startDate: '20260812',
    endDate: '20260812',
  };

  expect(expandServiceDates([single], [])).toEqual([{ serviceId: 'ONE', date: '2026-08-12' }]);
});

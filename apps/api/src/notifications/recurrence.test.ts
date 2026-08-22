import { expect, test } from 'bun:test';

import { nextOccurrence, scheduleDedupeKey } from './recurrence';

const everyDay = {
  daysOfWeek: [0, 1, 2, 3, 4, 5, 6],
  departureMinute: 8 * 60,
  leadMinutes: 0,
  skipHolidays: false,
  enabled: true,
  deletedAt: undefined,
};

test('recurrence uses the Paris wall clock through the spring DST gap', () => {
  const schedule = { ...everyDay, departureMinute: 2 * 60 + 30 };

  expect(nextOccurrence(schedule, new Date('2026-03-29T00:00:00.000Z'))).toEqual(
    new Date('2026-03-29T01:30:00.000Z'),
  );
});

test('recurrence picks the first occurrence of an ambiguous autumn hour', () => {
  const schedule = { ...everyDay, departureMinute: 2 * 60 + 30 };

  expect(nextOccurrence(schedule, new Date('2026-10-25T00:00:00.000Z'))).toEqual(
    new Date('2026-10-25T01:30:00.000Z'),
  );
});

test('recurrence skips French holidays while preserving the weekday mask', () => {
  const schedule = {
    ...everyDay,
    daysOfWeek: [5], // Friday
    skipHolidays: true,
  };

  expect(nextOccurrence(schedule, new Date('2026-04-30T00:00:00.000Z'))).toEqual(
    new Date('2026-05-15T06:00:00.000Z'),
  );
});

test('dedupe keys use the local departure date and minute', () => {
  expect(scheduleDedupeKey('schedule-1', '2026-10-25', 150)).toBe(
    'schedule-1:2026-10-25:150',
  );
});

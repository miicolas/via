import type { NotificationSchedule } from '@via/contract';

import { frenchHolidays, parisDate, parisWeekday, nextDate, toInstant } from '../time/paris';

// A weekly schedule can skip two consecutive French holidays (1 and 8 May),
// so one calendar week is not enough to find the next valid occurrence.
const MAX_SEARCH_DAYS = 42;

/**
 * Returns the next wall-clock firing for a Paris schedule. The schedule day is
 * the departure day; a lead time crossing midnight is intentionally resolved by
 * `toInstant`, just like GTFS service-day times.
 */
export function nextOccurrence(
  schedule: Pick<
    NotificationSchedule,
    | 'daysOfWeek'
    | 'departureMinute'
    | 'leadMinutes'
    | 'skipHolidays'
    | 'enabled'
    | 'deletedAt'
  >,
  after: Date,
): Date | null {
  if (!schedule.enabled || schedule.deletedAt != null) return null;
  if (schedule.daysOfWeek.length === 0) return null;

  let date = parisDate(after);
  for (let offset = 0; offset < MAX_SEARCH_DAYS; offset += 1) {
    const dateInstant = new Date(`${date}T12:00:00.000Z`);
    const weekday = parisWeekday(dateInstant);
    const holiday = schedule.skipHolidays && frenchHolidays(Number(date.slice(0, 4))).has(date);
    if (schedule.daysOfWeek.includes(weekday) && !holiday) {
      const fireSeconds = schedule.departureMinute * 60 - schedule.leadMinutes * 60;
      const candidate = new Date(toInstant(date, fireSeconds));
      if (candidate.getTime() > after.getTime()) return candidate;
    }
    date = nextDate(date);
  }
  return null;
}

/** Stable local identity used by materialization and autumn-DST deduplication. */
export function scheduleDedupeKey(
  scheduleId: string,
  departureDate: string,
  departureMinute: number,
): string {
  return `${scheduleId}:${departureDate}:${departureMinute}`;
}

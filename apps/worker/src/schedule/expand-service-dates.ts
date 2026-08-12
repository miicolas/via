export type CalendarRow = {
  serviceId: string;
  /** Monday first, GTFS column order. */
  weekdays: [boolean, boolean, boolean, boolean, boolean, boolean, boolean];
  /** GTFS dates, "YYYYMMDD". */
  startDate: string;
  endDate: string;
};

export type CalendarDateRow = {
  serviceId: string;
  date: string;
  /** GTFS `exception_type`: 1 adds the day, 2 removes it. */
  exceptionType: number;
};

/**
 * `calendar` weekly bitmaps + `calendar_dates` exceptions → the explicit set
 * of days each service runs, as ISO dates. Pure calendar arithmetic in UTC —
 * the dates are day labels, not instants, so timezones cannot bend them.
 */
export function expandServiceDates(
  calendar: CalendarRow[],
  exceptions: CalendarDateRow[]
): Array<{ serviceId: string; date: string }> {
  const daysByService = new Map<string, Set<string>>();
  const daysOf = (serviceId: string) => {
    const days = daysByService.get(serviceId) ?? new Set<string>();
    daysByService.set(serviceId, days);
    return days;
  };

  for (const row of calendar) {
    const days = daysOf(row.serviceId);
    const end = parseGtfsDate(row.endDate);
    for (let day = parseGtfsDate(row.startDate); day <= end; day += DAY_MS) {
      // getUTCDay: Sunday 0 — GTFS weekday columns start on Monday.
      if (row.weekdays[(new Date(day).getUTCDay() + 6) % 7]) days.add(isoDate(day));
    }
  }

  for (const exception of exceptions) {
    const day = isoDate(parseGtfsDate(exception.date));
    if (exception.exceptionType === 1) daysOf(exception.serviceId).add(day);
    if (exception.exceptionType === 2) daysByService.get(exception.serviceId)?.delete(day);
  }

  return [...daysByService].flatMap(([serviceId, days]) =>
    [...days].map((date) => ({ serviceId, date }))
  );
}

const DAY_MS = 86_400_000;

function parseGtfsDate(value: string): number {
  const match = /^(\d{4})(\d{2})(\d{2})$/.exec(value.trim());
  if (!match) throw new Error(`Not a GTFS date: "${value}"`);
  return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

function isoDate(utcMidnight: number): string {
  return new Date(utcMidnight).toISOString().slice(0, 10);
}

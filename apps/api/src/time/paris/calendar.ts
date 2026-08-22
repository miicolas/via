import { parisDate } from './day';

export type ParisDayType = 'weekday' | 'saturday' | 'sunday';

const HOLIDAYS_BY_YEAR = new Map<number, ReadonlySet<string>>();

/** French national public holidays for one Gregorian year. */
export function frenchHolidays(year: number): ReadonlySet<string> {
  const cached = HOLIDAYS_BY_YEAR.get(year);
  if (cached) return cached;

  const easter = easterSunday(year);
  const holidays = new Set([
    `${year}-01-01`,
    `${year}-05-01`,
    `${year}-05-08`,
    `${year}-07-14`,
    `${year}-08-15`,
    `${year}-11-01`,
    `${year}-11-11`,
    `${year}-12-25`,
    addDays(easter, 1),
    addDays(easter, 39),
    addDays(easter, 50),
  ]);
  HOLIDAYS_BY_YEAR.set(year, holidays);
  return holidays;
}

/** Resolves an instant using the Paris civil date, never the host timezone. */
export function parisDayType(instant: Date): ParisDayType {
  const date = parisDate(instant);
  const year = Number(date.slice(0, 4));
  if (frenchHolidays(year).has(date)) return 'sunday';

  const weekday = new Date(`${date}T00:00:00Z`).getUTCDay();
  if (weekday === 0) return 'sunday';
  if (weekday === 6) return 'saturday';
  return 'weekday';
}

/** ISO-date weekday on the Paris civil calendar (Sunday = 0, like Date). */
export function parisWeekday(instant: Date): 0 | 1 | 2 | 3 | 4 | 5 | 6 {
  const date = parisDate(instant);
  return new Date(`${date}T00:00:00Z`).getUTCDay() as 0 | 1 | 2 | 3 | 4 | 5 | 6;
}

/** Meeus/Gauss computus for Gregorian Easter Sunday. */
function easterSunday(year: number): string {
  const a = year % 19;
  const b = Math.floor(year / 100);
  const c = year % 100;
  const d = Math.floor(b / 4);
  const e = b % 4;
  const f = Math.floor((b + 8) / 25);
  const g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30;
  const i = Math.floor(c / 4);
  const k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7;
  const m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31);
  const day = ((h + l - 7 * m + 114) % 31) + 1;
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function addDays(date: string, days: number): string {
  return new Date(Date.parse(`${date}T00:00:00Z`) + days * 86_400_000)
    .toISOString()
    .slice(0, 10);
}

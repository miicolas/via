/**
 * The single home for Europe/Paris calendar, clock and formatting logic. The
 * server runs in UTC, so nothing here may lean on the host timezone — and no
 * other module may build its own Paris `Intl.DateTimeFormat`.
 */

/**
 * Where an instant sits in the transit calendar: which day it belongs to, and
 * how far into that day it is.
 */
export type ParisDay = {
  /** ISO date, e.g. "2026-08-12". */
  date: string;
  /** Seconds since that day's local midnight. */
  seconds: number;
};

// Built once: the constructor is one of the most expensive in the stdlib, and
// `toInstant` runs per row on the fallback path. Formatters are stateless.
const PARIS_PARTS_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Paris',
  hour12: false,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
});

const PARIS_TIME_FORMATTER = new Intl.DateTimeFormat('fr-FR', {
  timeZone: 'Europe/Paris',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

const PARIS_LONG_DATE_FORMATTER = new Intl.DateTimeFormat('fr-FR', {
  timeZone: 'Europe/Paris',
  weekday: 'long',
  day: 'numeric',
  month: 'long',
});

export function parisDay(instant: Date): ParisDay {
  const parts = partsInParis(instant);
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    seconds: Number(parts.hour) * 3600 + Number(parts.minute) * 60 + Number(parts.second),
  };
}

/** The Paris civil date of an instant, e.g. "2026-08-12". */
export function parisDate(instant: Date): string {
  return parisDay(instant).date;
}

/** The day before a service day — where after-midnight departures come from. */
export function previousDate(date: string): string {
  return new Date(Date.parse(`${date}T00:00:00Z`) - 86_400_000).toISOString().slice(0, 10);
}

/**
 * Service-day seconds back to a real instant, DST included: build the naive
 * local time, then ask what UTC offset Paris had at that moment. Seconds past
 * 86 400 roll into the following calendar day, which is exactly what a
 * "25:12:00" departure means.
 */
export function toInstant(date: string, seconds: number): string {
  const naiveUtc = Date.parse(`${date}T00:00:00Z`) + seconds * 1000;
  // Two passes: the offset is evaluated at a guess, then re-checked at the
  // corrected instant, so a departure inside a DST switch lands right.
  const firstGuess = naiveUtc - parisOffsetMs(new Date(naiveUtc));
  const instant = naiveUtc - parisOffsetMs(new Date(firstGuess));
  return new Date(instant).toISOString();
}

/** Paris wall-clock time of an ISO instant, e.g. "9 h 05" or "9h05". */
export function formatParisTime(value: string, separator: ' h ' | 'h' = ' h '): string {
  return PARIS_TIME_FORMATTER.format(new Date(value)).replace(':', separator);
}

/** Paris long date of an ISO instant, e.g. "mercredi 12 août". */
export function formatParisLongDate(value: string): string {
  return PARIS_LONG_DATE_FORMATTER.format(new Date(value));
}

/** Navitia's compact Paris-local datetime, e.g. "20260812T215000". */
export function compactParisDateTime(instant: Date): string {
  const { date, seconds } = parisDay(instant);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${date.replaceAll('-', '')}T${pad(hours)}${pad(minutes)}${pad(seconds % 60)}`;
}

type DateParts = Record<'year' | 'month' | 'day' | 'hour' | 'minute' | 'second', string>;

function partsInParis(instant: Date): DateParts {
  const parts = Object.fromEntries(
    PARIS_PARTS_FORMATTER.formatToParts(instant).map(({ type, value }) => [type, value])
  ) as DateParts;

  // Intl renders midnight as hour 24 in some engines; normalize it.
  return { ...parts, hour: parts.hour === '24' ? '00' : parts.hour };
}

function parisOffsetMs(instant: Date): number {
  const parts = partsInParis(instant);
  const asUtc = Date.UTC(
    Number(parts.year),
    Number(parts.month) - 1,
    Number(parts.day),
    Number(parts.hour),
    Number(parts.minute),
    Number(parts.second)
  );
  return asUtc - Math.floor(instant.getTime() / 1000) * 1000;
}

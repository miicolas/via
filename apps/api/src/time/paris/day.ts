import { parisOffsetMs, partsInParis } from './zone';

/** Where an instant sits in the transit calendar. */
export type ParisDay = {
  /** ISO date, e.g. "2026-08-12". */
  date: string;
  /** Seconds since that day's local midnight. */
  seconds: number;
};

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

/** The following Gregorian civil date, independent of the host timezone. */
export function nextDate(date: string): string {
  return new Date(Date.parse(`${date}T00:00:00Z`) + 86_400_000).toISOString().slice(0, 10);
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

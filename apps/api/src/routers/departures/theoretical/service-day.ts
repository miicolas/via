/**
 * Where an instant sits in the transit calendar: which service day it belongs
 * to, and how far into that day it is. Both are Paris facts — the server runs
 * in UTC, so nothing here may lean on the host timezone.
 */
export type ServiceDayPosition = {
  /** ISO date of the service day, e.g. "2026-08-12". */
  date: string;
  /** Seconds since that day's local midnight. */
  seconds: number;
};

// Built once: the constructor is one of the most expensive in the stdlib, and
// `toInstant` runs per row on the fallback path. Formatters are stateless.
const PARIS_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Paris',
  hour12: false,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
});

export function parisServiceDay(now: Date): ServiceDayPosition {
  const parts = partsInParis(now);
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    seconds: Number(parts.hour) * 3600 + Number(parts.minute) * 60 + Number(parts.second),
  };
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

type DateParts = Record<'year' | 'month' | 'day' | 'hour' | 'minute' | 'second', string>;

function partsInParis(instant: Date): DateParts {
  const parts = Object.fromEntries(
    PARIS_FORMATTER.formatToParts(instant).map(({ type, value }) => [type, value])
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

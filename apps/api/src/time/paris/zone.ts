/**
 * Private Europe/Paris timezone primitives.
 *
 * The public module is intentionally split into calendar, day and formatting
 * concepts, but every one of them must use these formatter instances. Keeping
 * this file private makes the "single home for Europe/Paris" rule structural:
 * no caller can quietly construct a formatter with the host timezone.
 */

export const PARIS_PARTS_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Paris',
  hour12: false,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
});

export const PARIS_TIME_FORMATTER = new Intl.DateTimeFormat('fr-FR', {
  timeZone: 'Europe/Paris',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

export const PARIS_LONG_DATE_FORMATTER = new Intl.DateTimeFormat('fr-FR', {
  timeZone: 'Europe/Paris',
  weekday: 'long',
  day: 'numeric',
  month: 'long',
});

export type DateParts = Record<'year' | 'month' | 'day' | 'hour' | 'minute' | 'second', string>;

export function partsInParis(instant: Date): DateParts {
  const parts = Object.fromEntries(
    PARIS_PARTS_FORMATTER.formatToParts(instant).map(({ type, value }) => [type, value])
  ) as DateParts;

  // Intl renders midnight as hour 24 in some engines; normalize it.
  return { ...parts, hour: parts.hour === '24' ? '00' : parts.hour };
}

export function parisOffsetMs(instant: Date): number {
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

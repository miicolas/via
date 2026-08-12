/**
 * "HH:MM:SS" → seconds since the service day's midnight. GTFS lets hours run
 * past 24 for after-midnight departures of the previous day's service —
 * "25:12:00" is 1:12 the next morning and must stay attached to its service
 * day, so no modulo here.
 */
export function parseGtfsTime(value: string): number {
  const match = /^(\d+):([0-5]\d):([0-5]\d)$/.exec(value.trim());
  if (!match) throw new Error(`Not a GTFS time: "${value}"`);

  const [, hours, minutes, seconds] = match;
  return Number(hours) * 3600 + Number(minutes) * 60 + Number(seconds);
}

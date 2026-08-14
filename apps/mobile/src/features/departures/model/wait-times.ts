export type WaitTimes = {
  /** Full minutes until the next departure — 0 means it is at the platform. */
  primaryMinutes: number;
  /** The next announced departures, kept numeric for compact departure boards. */
  followingMinutes?: number[];
  /** The ones after that, e.g. "puis 4 et 9 min". Absent when nothing follows. */
  followingLabel?: string;
};

const FOLLOWING_SHOWN = 2;

/**
 * Departure timestamps → what the row displays, floored so "1 min" still
 * means the train is at least a minute away. The server already dropped past
 * departures, but the client clock keeps moving between polls — hence the
 * re-filter against `now` (with a beat of grace for a train currently boarding).
 */
export function waitTimes(departures: string[], now: Date): WaitTimes | undefined {
  const GRACE_MS = 30_000;

  const minutes = departures
    .map((iso) => Date.parse(iso) - now.getTime())
    .filter((wait) => wait > -GRACE_MS)
    .map((wait) => Math.max(0, Math.floor(wait / 60_000)));

  if (minutes.length === 0) return undefined;

  const [primary, ...following] = minutes;
  const shown = following.slice(0, FOLLOWING_SHOWN);

  return {
    primaryMinutes: primary,
    followingMinutes: shown.length > 0 ? shown : undefined,
    followingLabel:
      shown.length > 0 ? `puis ${shown.join(' et ')} min` : undefined,
  };
}

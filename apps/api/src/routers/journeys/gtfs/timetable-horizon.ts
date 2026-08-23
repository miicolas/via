import { db, importMeta } from '@via/db';
import { TIMETABLE_HORIZON_KEY } from '@via/db/timetable';
import { eq } from 'drizzle-orm';

/**
 * How long a horizon read is reused inside one process. The value only changes
 * when a GTFS import runs, so this is about not issuing the read on every
 * journey rather than about freshness.
 */
const CACHE_TTL_MS = 60_000;

/** No recorded horizon means "search everything" — see `readTimetableHorizon`. */
export const UNKNOWN_TIMETABLE_HORIZON = Number.POSITIVE_INFINITY;

let cached: { seconds: number; expiresAt: number } | undefined;

/**
 * The latest absolute second the timetable reaches, as measured at import.
 *
 * Returns `UNKNOWN_TIMETABLE_HORIZON` when the key is missing (a database from
 * before the importer wrote it, or an empty timetable) or unreadable. That is
 * the safe direction: an infinite horizon makes every caller conclude that
 * yesterday's services might still be running, which is exactly the behaviour
 * that existed before this value did. Erring the other way would silently drop
 * real departures.
 */
export async function readTimetableHorizon(): Promise<number> {
  const now = Date.now();
  if (cached && cached.expiresAt > now) return cached.seconds;

  let seconds = UNKNOWN_TIMETABLE_HORIZON;
  try {
    const [row] = await db
      .select({ value: importMeta.value })
      .from(importMeta)
      .where(eq(importMeta.key, TIMETABLE_HORIZON_KEY))
      .limit(1);
    const parsed = row === undefined ? Number.NaN : Number(row.value);
    if (Number.isFinite(parsed)) seconds = parsed;
  } catch (cause) {
    // The planner is about to hit the same database anyway; if it is down the
    // real error belongs to that query, not to this optimization.
    console.error('[journeys] timetable horizon unavailable', cause);
  }

  cached = { seconds, expiresAt: now + CACHE_TTL_MS };
  return seconds;
}

/** Test seam: the memo outlives a single test otherwise. */
export function resetTimetableHorizonCache() {
  cached = undefined;
}

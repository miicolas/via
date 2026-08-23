import { jobDb, timestamptz } from '@via/db';
import { sql } from 'drizzle-orm';

import { redis } from '../redis';

const HOUR_MILLISECONDS = 60 * 60 * 1_000;
const RETENTION_MILLISECONDS = 7 * 24 * HOUR_MILLISECONDS;
const BATCH_SIZE = 500;
let timer: ReturnType<typeof setInterval> | undefined;

export function reportRetentionCutoff(now: Date) {
  return new Date(now.getTime() - RETENTION_MILLISECONDS);
}

export function startReportRuntime() {
  if (process.env.NODE_ENV === 'test' || timer) return;
  const run = () => void purgeIfElected().catch((error) =>
    console.error('[reports] retention purge failed', error));
  run();
  timer = setInterval(run, HOUR_MILLISECONDS);
}

export function stopReportRuntime() {
  if (timer) clearInterval(timer);
  timer = undefined;
}

async function purgeIfElected(now = new Date()) {
  const cycle = Math.floor(now.getTime() / HOUR_MILLISECONDS);
  const elected = await redis.set(`reports:retention:${cycle}`, '1', { nx: true, ex: 65 * 60 });
  if (!elected) return;
  await purgeExpiredReports(reportRetentionCutoff(now));
}

/** Each hourly cycle deletes at most one bounded batch from each report table. */
export async function purgeExpiredReports(before: Date) {
  const events = await jobDb.execute<{ id: string }>(sql`
    DELETE FROM report_events AS event
    WHERE event.id IN (
      SELECT candidate.id FROM report_events AS candidate
      WHERE candidate.created_at < ${timestamptz(before)}
      ORDER BY candidate.created_at, candidate.id
      LIMIT ${BATCH_SIZE}
    )
    RETURNING event.id
  `);
  const votes = await jobDb.execute<{ userId: string }>(sql`
    DELETE FROM report_current_votes AS vote
    WHERE vote.ctid IN (
      SELECT candidate.ctid FROM report_current_votes AS candidate
      WHERE candidate.updated_at < ${timestamptz(before)}
      ORDER BY candidate.updated_at
      LIMIT ${BATCH_SIZE}
    )
    RETURNING vote.user_id AS "userId"
  `);
  return { events: events.length, votes: votes.length };
}

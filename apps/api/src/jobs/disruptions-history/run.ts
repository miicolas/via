import { db, disruptionHistory } from '@via/db';
import { inArray, sql } from 'drizzle-orm';

import { toDisruptionRecord, type DisruptionRecord } from './record';
import { selectTopics, type KnownDisruption, type TopicReport } from './topics';
import { redis } from '../../redis';
import { getDisruptionsSnapshot } from '../../routers/lines/disruptions/snapshot';

/**
 * Postgres caps a statement at 65535 bound parameters and this table has
 * thirteen columns, so five hundred rows a statement stays far clear of it
 * while keeping the whole pass to a handful of round-trips.
 */
const CHUNK_SIZE = 500;

export type HistoryRunResult = {
  report: TopicReport;
  written: number;
};

/**
 * One pass of the disruption history: read the feed the API already reads,
 * keep every disruption it carried, and hand back the shortlist of subjects
 * worth writing about.
 *
 * It goes through `getDisruptionsSnapshot` rather than calling PRIM itself, so
 * it obeys the same daily budget and single-flight lock as every request — a
 * scheduled job must not be the reason a rider's Lines tab finds the quota
 * spent.
 */
export async function runDisruptionsHistory(now = new Date()): Promise<HistoryRunResult> {
  const snapshot = await getDisruptionsSnapshot(redis, now);
  if (!snapshot) {
    throw new Error('PRIM disruptions unavailable: nothing to record this pass.');
  }

  const records = snapshot.disruptions.map(toDisruptionRecord);
  const known = await readKnownHashes(records.map((record) => record.id));
  const topics = selectTopics(records, known, now);

  const written = await writeRecords(records, now);

  return {
    report: {
      generatedAt: now.toISOString(),
      seen: records.length,
      topics,
    },
    written,
  };
}

/**
 * The hashes of the disruptions this pass is about to write, as they stand.
 * Read before the upsert, because after it every row looks unchanged.
 */
async function readKnownHashes(ids: readonly string[]): Promise<Map<string, KnownDisruption>> {
  const known = new Map<string, KnownDisruption>();
  if (ids.length === 0) return known;

  for (let offset = 0; offset < ids.length; offset += CHUNK_SIZE) {
    const chunk = ids.slice(offset, offset + CHUNK_SIZE);
    const rows = await db
      .select({ id: disruptionHistory.id, contentHash: disruptionHistory.contentHash })
      .from(disruptionHistory)
      .where(inArray(disruptionHistory.id, chunk));

    for (const row of rows) known.set(row.id, { contentHash: row.contentHash });
  }

  return known;
}

/**
 * Upsert on PRIM's id. `lastSeenAt` moves every pass — that is how a
 * disappeared disruption becomes visible — while `changedAt` only moves when
 * the content hash actually differs, so "the feed republished it" and "the
 * dates moved" stay distinguishable.
 */
async function writeRecords(records: readonly DisruptionRecord[], now: Date): Promise<number> {
  let written = 0;

  for (let offset = 0; offset < records.length; offset += CHUNK_SIZE) {
    const chunk = records.slice(offset, offset + CHUNK_SIZE);
    if (chunk.length === 0) continue;

    await db
      .insert(disruptionHistory)
      .values(
        chunk.map((record) => ({
          ...record,
          firstSeenAt: now,
          lastSeenAt: now,
          changedAt: now,
        }))
      )
      .onConflictDoUpdate({
        target: disruptionHistory.id,
        set: {
          severity: sql`excluded.severity`,
          cause: sql`excluded.cause`,
          title: sql`excluded.title`,
          message: sql`excluded.message`,
          routeIds: sql`excluded.route_ids`,
          periods: sql`excluded.periods`,
          impactedSections: sql`excluded.impacted_sections`,
          upstreamUpdatedAt: sql`excluded.upstream_updated_at`,
          beginsAt: sql`excluded.begins_at`,
          endsAt: sql`excluded.ends_at`,
          lastSeenAt: sql`excluded.last_seen_at`,
          contentHash: sql`excluded.content_hash`,
          changedAt: sql`case
            when ${disruptionHistory.contentHash} is distinct from excluded.content_hash
            then excluded.changed_at
            else ${disruptionHistory.changedAt}
          end`,
        },
      });

    written += chunk.length;
  }

  return written;
}

import { sql } from 'drizzle-orm';
import {
  jobDb,
  notificationOccurrences,
  type NotificationOccurrence,
} from '@via/db';
import type { NotificationCategory, NotificationDropReason } from '@via/contract';

export type ClaimedNotificationOccurrence = NotificationOccurrence & {
  badge: number;
  sentToday: number;
};

type RawClaimedOccurrence = Omit<ClaimedNotificationOccurrence, 'badge' | 'sentToday'> & {
  badge: number | string;
  sentToday: number | string;
};

export interface NotificationOccurrenceStore {
  insert(input: {
    id?: string;
    userId: string;
    scheduleId?: string;
    category: NotificationCategory;
    scheduleRevision: number;
    dueAt: Date;
    dedupeKey: string;
    payload: Record<string, unknown>;
  }): Promise<void>;
  claimDue(limit: number, shard: number): Promise<ClaimedNotificationOccurrence[]>;
  reapExpired(limit: number, now?: Date): Promise<number>;
  finish(ids: readonly string[], state: 'sent' | 'dropped', reason?: NotificationDropReason): Promise<void>;
  purgeTerminal?(before: Date, limit: number): Promise<number>;
}

/** The only store allowed to claim an occurrence; it never holds a transaction during APNs I/O. */
export function createDatabaseNotificationOccurrenceStore(): NotificationOccurrenceStore {
  return {
    async insert(input) {
      await jobDb
        .insert(notificationOccurrences)
        .values({
          id: input.id ?? crypto.randomUUID(),
          userId: input.userId,
          scheduleId: input.scheduleId ?? null,
          category: input.category,
          scheduleRevision: input.scheduleRevision,
          dueAt: input.dueAt,
          dedupeKey: input.dedupeKey,
          payload: input.payload,
        })
        .onConflictDoNothing({ target: notificationOccurrences.dedupeKey });
    },

    async claimDue(limit, shard) {
      const result = await jobDb.execute<RawClaimedOccurrence>(sql`
        UPDATE notification_occurrences AS o
        SET state = 'sending',
            lease_until = now() + interval '2 minutes',
            attempts = o.attempts + 1
        WHERE o.id = ANY (
          SELECT candidate.id
          FROM notification_occurrences AS candidate
          WHERE candidate.state = 'pending'
            AND candidate.due_at <= now()
            AND candidate.delivery_shard = ${shard}
          ORDER BY candidate.due_at, candidate.id
          LIMIT ${limit}
          FOR UPDATE SKIP LOCKED
        )
        RETURNING
          o.id,
          o.user_id AS "userId",
          o.schedule_id AS "scheduleId",
          o.category,
          o.schedule_revision AS "scheduleRevision",
          o.due_at AS "dueAt",
          o.state,
          o.drop_reason AS "dropReason",
          o.attempts,
          o.lease_until AS "leaseUntil",
          o.dedupe_key AS "dedupeKey",
          o.payload,
          o.delivery_shard AS "deliveryShard",
          (
            SELECT count(*)::int FROM notification_inbox i
            WHERE i.user_id = o.user_id
              AND i.read_at IS NULL
          ) AS badge,
          (
            SELECT count(*)::int FROM notification_inbox i
            WHERE i.user_id = o.user_id
              AND i.category = o.category
              AND i.drop_reason IS NULL
              AND i.created_at >= (
                date_trunc('day', now() AT TIME ZONE 'Europe/Paris')
                AT TIME ZONE 'Europe/Paris'
              )
          ) AS "sentToday"
      `);
      return result.map((row) => ({
        ...row,
        badge: Number(row.badge),
        sentToday: Number(row.sentToday),
      }));
    },

    async reapExpired(limit, now = new Date()) {
      const result = await jobDb.execute<{ id: string }>(sql`
        UPDATE notification_occurrences AS occurrence
        SET state = CASE WHEN occurrence.attempts >= 5 THEN 'dropped' ELSE 'pending' END,
            drop_reason = CASE WHEN occurrence.attempts >= 5 THEN 'stale' ELSE occurrence.drop_reason END,
            lease_until = NULL
        WHERE occurrence.id IN (
          SELECT candidate.id
          FROM notification_occurrences AS candidate
          WHERE candidate.state = 'sending'
            AND candidate.lease_until < ${now}
          ORDER BY candidate.lease_until, candidate.id
          LIMIT ${limit}
          FOR UPDATE SKIP LOCKED
        )
        RETURNING occurrence.id
      `);
      return result.length;
    },

    async finish(ids, state, reason) {
      if (ids.length === 0) return;
      await jobDb.execute(sql`
        UPDATE notification_occurrences
        SET state = ${state},
            drop_reason = ${reason ?? null},
            lease_until = NULL
        WHERE id = ANY(${ids}::text[])
          AND state = 'sending'
      `);
    },

    async purgeTerminal(before, limit) {
      const result = await jobDb.execute<{ id: string }>(sql`
        DELETE FROM notification_occurrences AS occurrence
        WHERE occurrence.id IN (
          SELECT candidate.id
          FROM notification_occurrences AS candidate
          WHERE candidate.state IN ('sent', 'dropped')
            AND candidate.due_at < ${before}
          ORDER BY candidate.due_at, candidate.id
          LIMIT ${limit}
        )
        RETURNING occurrence.id
      `);
      return result.length;
    },
  };
}

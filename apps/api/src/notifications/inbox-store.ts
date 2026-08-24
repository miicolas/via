import { and, desc, eq, isNull, lt, or, sql } from 'drizzle-orm';
import {
  db,
  jobDb,
  notificationInbox,
  notificationOccurrences,
  notificationMutes,
  timestamptz,
  type NotificationCategory,
  type NotificationSeverity,
} from '@via/db';
import type {
  NotificationDropReason,
  NotificationInboxPage,
} from '@via/contract';
import { parisDate, toInstant } from '../time/paris';

type InboxDatabase = typeof db | typeof jobDb;
type InboxRow = typeof notificationInbox.$inferInsert;

export type NotificationInboxInsert = Pick<
  InboxRow,
  'userId' | 'occurrenceId' | 'category' | 'title' | 'body' | 'deepLink' | 'topicKind' | 'topicId' | 'severity' | 'dropReason'
> & { id?: string };

export interface NotificationInboxStore {
  insert(input: NotificationInboxInsert): Promise<string>;
  list(userId: string, input: { cursor?: string; limit: number }): Promise<NotificationInboxPage>;
  markRead(userId: string, readBefore: Date): Promise<void>;
  unreadCount(userId: string): Promise<number>;
  sentToday?(userId: string, at?: Date, category?: NotificationCategory): Promise<number>;
  purge?(before: Date, limit: number): Promise<number>;
}

export function createDatabaseNotificationInboxStore(database: InboxDatabase = db): NotificationInboxStore {
  return {
    async insert(input) {
      const id = input.id ?? crypto.randomUUID();
      await database
        .insert(notificationInbox)
        .values({ ...input, id })
        .onConflictDoNothing();
      return id;
    },

    async list(userId, input) {
      const cursor = input.cursor ? decodeCursor(input.cursor) : undefined;
      const rows = await database
        .select()
        .from(notificationInbox)
        .where(
          and(
            eq(notificationInbox.userId, userId),
            cursor
              ? or(
                  lt(notificationInbox.createdAt, cursor.createdAt),
                  and(
                    eq(notificationInbox.createdAt, cursor.createdAt),
                    lt(notificationInbox.id, cursor.id),
                  ),
                )
              : undefined,
          ),
        )
        .orderBy(desc(notificationInbox.createdAt), desc(notificationInbox.id))
        .limit(input.limit + 1);

      const hasNext = rows.length > input.limit;
      const items = rows.slice(0, input.limit).map(toInboxItem);
      const last = rows[input.limit - 1];
      return {
        items,
        ...(hasNext && last
          ? { nextCursor: encodeCursor({ createdAt: last.createdAt, id: last.id }) }
          : {}),
        unreadCount: await this.unreadCount(userId),
      };
    },

    async markRead(userId, readBefore) {
      await database
        .update(notificationInbox)
        .set({ readAt: new Date() })
        .where(
          and(
            eq(notificationInbox.userId, userId),
            isNull(notificationInbox.readAt),
            sql`${notificationInbox.createdAt} <= ${readBefore}`,
          ),
        );
    },

    async unreadCount(userId) {
      const result = await database
        .select({ count: sql<number>`count(*)::int` })
        .from(notificationInbox)
        .where(and(eq(notificationInbox.userId, userId), isNull(notificationInbox.readAt)));
      return result[0]?.count ?? 0;
    },

    async sentToday(userId, at = new Date(), category) {
      const result = await database
        .select({ count: sql<number>`count(*)::int` })
        .from(notificationInbox)
        .where(notificationSentTodayWhere(userId, at, category));
      return result[0]?.count ?? 0;
    },

    async purge(before, limit) {
      const result = await database.execute<{ id: string }>(sql`
        DELETE FROM notification_inbox AS item
        WHERE item.id IN (
          SELECT candidate.id
          FROM notification_inbox AS candidate
          WHERE candidate.created_at < ${timestamptz(before)}
          ORDER BY candidate.created_at, candidate.id
          LIMIT ${limit}
        )
        RETURNING item.id
      `);
      return result.length;
    },
  };
}

export function notificationSentTodayWhere(
  userId: string,
  at: Date,
  category?: NotificationCategory,
) {
  const startOfDay = new Date(toInstant(parisDate(at), 0));
  return and(
    eq(notificationInbox.userId, userId),
    category ? eq(notificationInbox.category, category) : undefined,
    isNull(notificationInbox.dropReason),
    sql`${notificationInbox.createdAt} >= ${timestamptz(startOfDay)}`,
  )!;
}

export function encodeCursor(cursor: { createdAt: Date; id: string }): string {
  return Buffer.from(JSON.stringify({ at: cursor.createdAt.toISOString(), id: cursor.id })).toString('base64url');
}

export function decodeCursor(value: string): { createdAt: Date; id: string } | undefined {
  try {
    const decoded = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as {
      at?: unknown;
      id?: unknown;
    };
    if (typeof decoded.at !== 'string' || typeof decoded.id !== 'string') return undefined;
    const createdAt = new Date(decoded.at);
    return Number.isFinite(createdAt.getTime()) && decoded.id.length > 0
      ? { createdAt, id: decoded.id }
      : undefined;
  } catch {
    return undefined;
  }
}

function toInboxItem(row: typeof notificationInbox.$inferSelect) {
  return {
    id: row.id,
    occurrenceId: row.occurrenceId ?? undefined,
    category: row.category as NotificationCategory,
    title: row.title,
    body: row.body,
    deepLink: row.deepLink ?? undefined,
    topicKind: row.topicKind ?? undefined,
    topicId: row.topicId ?? undefined,
    severity: (row.severity ?? undefined) as NotificationSeverity | undefined,
    dropReason: (row.dropReason ?? undefined) as NotificationDropReason | undefined,
    createdAt: row.createdAt.toISOString(),
    readAt: row.readAt?.toISOString(),
  };
}

export async function muteNotification(
  userId: string,
  input: { scope: 'category' | 'topic'; key: string; mutedUntil?: Date },
) {
  await db
    .insert(notificationMutes)
    .values({ userId, scope: input.scope, key: input.key, mutedUntil: input.mutedUntil ?? null })
    .onConflictDoUpdate({
      target: [notificationMutes.userId, notificationMutes.scope, notificationMutes.key],
      set: { mutedUntil: input.mutedUntil ?? null },
    });
}

export async function snoozeNotification(userId: string, occurrenceId: string, until: Date) {
  const updated = await db
    .update(notificationOccurrences)
    .set({ dueAt: until, state: 'pending', leaseUntil: null })
    .where(and(eq(notificationOccurrences.id, occurrenceId), eq(notificationOccurrences.userId, userId)))
    .returning({ id: notificationOccurrences.id });
  return updated.length > 0;
}

import { and, eq, isNull } from 'drizzle-orm';
import { jobDb, notificationAlertSubscriptions } from '@via/db';
import type { NotificationAlertSubscription } from '@via/contract';

export interface NotificationAlertSubscriptionStore {
  listActive(topicKind: 'line' | 'station'): Promise<Array<NotificationAlertSubscription & { userId: string }>>;
  listForTopic(topicKind: 'line' | 'station', topicId: string): Promise<Array<NotificationAlertSubscription & { userId: string }>>;
}

export function createDatabaseNotificationAlertSubscriptionStore(): NotificationAlertSubscriptionStore {
  return {
    async listActive(topicKind) {
      const rows = await jobDb
        .select()
        .from(notificationAlertSubscriptions)
        .where(
          and(
            eq(notificationAlertSubscriptions.topicKind, topicKind),
            eq(notificationAlertSubscriptions.enabled, true),
            isNull(notificationAlertSubscriptions.deletedAt),
          ),
        );
      return rows.map(toSubscription);
    },
    async listForTopic(topicKind, topicId) {
      const rows = await jobDb
        .select()
        .from(notificationAlertSubscriptions)
        .where(
          and(
            eq(notificationAlertSubscriptions.topicKind, topicKind),
            eq(notificationAlertSubscriptions.topicId, topicId),
            eq(notificationAlertSubscriptions.enabled, true),
            isNull(notificationAlertSubscriptions.deletedAt),
          ),
        );
      return rows.map(toSubscription);
    },
  };
}

function toSubscription(row: typeof notificationAlertSubscriptions.$inferSelect) {
  return {
    ...row,
    topicKind: row.topicKind,
    savedAt: row.savedAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    deletedAt: row.deletedAt?.toISOString(),
    userId: row.userId,
  };
}

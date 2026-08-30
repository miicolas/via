import { and, eq, or, isNull, gt } from 'drizzle-orm';
import {
  jobDb,
  notificationMutes,
  notificationPreferences,
  notificationSchedules,
} from '@via/db';
import type { NotificationSchedule } from '@via/contract';

import type { DeliveryPolicyInput } from './policy';

export interface NotificationDispatcherScheduleStore {
  schedule(id: string): Promise<NotificationSchedule & { userId: string } | undefined>;
  preferences(userId: string): Promise<DeliveryPolicyInput['preferences']>;
  muted(userId: string, category: string, topicId?: string): Promise<boolean>;
}

export function createDatabaseNotificationDispatcherScheduleStore(): NotificationDispatcherScheduleStore {
  return {
    async schedule(id) {
      const rows = await jobDb
        .select()
        .from(notificationSchedules)
        .where(eq(notificationSchedules.id, id))
        .limit(1);
      const row = rows[0];
      return row
        ? {
            ...row,
            origin: row.origin ?? undefined,
            destination: row.destination ?? undefined,
            timeZone: 'Europe/Paris' as const,
            pausedUntil: row.pausedUntil?.toISOString(),
            savedAt: row.savedAt.toISOString(),
            updatedAt: row.updatedAt.toISOString(),
            deletedAt: row.deletedAt?.toISOString(),
            userId: row.userId,
          }
        : undefined;
    },
    async preferences(userId) {
      const rows = await jobDb
        .select()
        .from(notificationPreferences)
        .where(eq(notificationPreferences.userId, userId))
        .limit(1);
      const row = rows[0];
      return row
        ? {
            enabled: row.enabled,
            timeZone: 'Europe/Paris' as const,
            quietHoursStartMinute: row.quietHoursStartMinute ?? undefined,
            quietHoursEndMinute: row.quietHoursEndMinute ?? undefined,
            mutedOnWeekends: row.mutedOnWeekends,
            mutedOnHolidays: row.mutedOnHolidays,
            minimumSeverity: row.minimumSeverity,
            dailyCap: row.dailyCap,
            categories: row.categories,
            updatedAt: row.updatedAt.toISOString(),
          }
        : null;
    },
    async muted(userId, category, topicId) {
      const rows = await jobDb
        .select({ key: notificationMutes.key, mutedUntil: notificationMutes.mutedUntil })
        .from(notificationMutes)
        .where(
          and(
            eq(notificationMutes.userId, userId),
            or(
              and(eq(notificationMutes.scope, 'category'), eq(notificationMutes.key, category)),
              topicId
                ? and(eq(notificationMutes.scope, 'topic'), eq(notificationMutes.key, topicId))
                : undefined,
            ),
            or(isNull(notificationMutes.mutedUntil), gt(notificationMutes.mutedUntil, new Date())),
          ),
        );
      return rows.length > 0;
    },
  };
}

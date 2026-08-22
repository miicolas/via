import { and, eq, isNull, sql } from 'drizzle-orm';
import {
  jobDb,
  notificationOccurrences,
  notificationPreferences,
  notificationSchedules,
} from '@via/db';
import type { NotificationPreferences, NotificationSchedule } from '@via/contract';

import { parisDay } from '../time/paris';
import { isNotificationQuietAt } from './policy';
import { nextOccurrence, scheduleDedupeKey } from './recurrence';
import { mergeNotificationPreferences } from './preferences';

export const MATERIALIZATION_HORIZON_MS = 26 * 60 * 60 * 1_000;
export const MATERIALIZATION_BUDGET_MS = 2_000;

export type MaterializationSchedule = NotificationSchedule & { userId: string };

export interface NotificationMaterializationStore {
  listActiveSchedules(shard: { index: number; count: number }): Promise<MaterializationSchedule[]>;
  latestDueAt(scheduleId: string): Promise<Date | undefined>;
  insertOccurrence(input: {
    userId: string;
    scheduleId: string;
    category: 'commute' | 'digest';
    scheduleRevision: number;
    dueAt: Date;
    dedupeKey: string;
    payload: Record<string, unknown>;
  }): Promise<void>;
  preferences(userId: string): Promise<NotificationPreferences | Partial<NotificationPreferences> | null>;
}

export class NotificationMaterializer {
  private isRunning = false;

  constructor(
    private readonly options: {
      store: NotificationMaterializationStore;
      now?: () => Date;
      budgetMilliseconds?: number;
      horizonMilliseconds?: number;
    },
  ) {}

  async pollOnce(shard: { index: number; count: number }): Promise<number> {
    if (this.isRunning) return 0;
    this.isRunning = true;
    const startedAt = Date.now();
    const now = this.options.now?.() ?? new Date();
    const horizon = new Date(
      now.getTime() + (this.options.horizonMilliseconds ?? MATERIALIZATION_HORIZON_MS),
    );
    let inserted = 0;
    try {
      const schedules = await this.options.store.listActiveSchedules(shard);
      for (const schedule of schedules) {
        if (Date.now() - startedAt >= (this.options.budgetMilliseconds ?? MATERIALIZATION_BUDGET_MS)) break;
        // The deterministic commute reminder is owned by iOS. The server
        // only materializes the enriched variant when it has at least one
        // route to intersect with the cached disruption snapshot.
        if (schedule.kind === 'commute' && schedule.routeIds.length === 0) continue;
        if (schedule.pausedUntil && Date.parse(schedule.pausedUntil) > now.getTime()) continue;
        let after = await this.options.store.latestDueAt(schedule.id);
        if (!after || after < now) after = after ?? new Date(now.getTime() - 1);

        for (;;) {
          const candidate = nextOccurrence(schedule, after);
          if (!candidate || candidate > horizon) break;
          const preferences = await this.options.store.preferences(schedule.userId);
          if (!isNotificationQuietAt(preferences, candidate)) {
            await this.options.store.insertOccurrence({
              userId: schedule.userId,
              scheduleId: schedule.id,
              category: schedule.kind,
              scheduleRevision: schedule.revision,
              dueAt: candidate,
              dedupeKey: scheduleDedupeKey(
                schedule.id,
                parisDay(candidate).date,
                Math.floor(parisDay(candidate).seconds / 60),
              ),
              payload: {
                scheduleId: schedule.id,
                scheduleRevision: schedule.revision,
                category: schedule.kind,
                label: schedule.label,
                routeIds: schedule.routeIds,
                origin: schedule.origin,
                destination: schedule.destination,
              },
            });
            inserted += 1;
          }
          after = candidate;
          if (Date.now() - startedAt >= (this.options.budgetMilliseconds ?? MATERIALIZATION_BUDGET_MS)) break;
        }
      }
      return inserted;
    } finally {
      this.isRunning = false;
    }
  }
}

export function createDatabaseNotificationMaterializationStore(): NotificationMaterializationStore {
  return {
    async listActiveSchedules(shard) {
      const rows = await jobDb
        .select()
        .from(notificationSchedules)
        .where(
          and(
            eq(notificationSchedules.enabled, true),
            isNull(notificationSchedules.deletedAt),
            sql`mod(hashtextextended(${notificationSchedules.userId}, 0) & 9223372036854775807, ${shard.count}) = ${shard.index}`,
          ),
        );
      return rows.map((row) => ({
        ...row,
        origin: row.origin ?? undefined,
        destination: row.destination ?? undefined,
        timeZone: 'Europe/Paris' as const,
        pausedUntil: row.pausedUntil?.toISOString(),
        savedAt: row.savedAt.toISOString(),
        updatedAt: row.updatedAt.toISOString(),
        deletedAt: row.deletedAt?.toISOString(),
        userId: row.userId,
      }));
    },

    async latestDueAt(scheduleId) {
      const rows = await jobDb
        .select({ latest: sql<Date | null>`max(${notificationOccurrences.dueAt})` })
        .from(notificationOccurrences)
        .where(eq(notificationOccurrences.scheduleId, scheduleId));
      return rows[0]?.latest ?? undefined;
    },

    async insertOccurrence(input) {
      await jobDb
        .insert(notificationOccurrences)
        .values({
          id: crypto.randomUUID(),
          ...input,
        })
        .onConflictDoNothing({ target: notificationOccurrences.dedupeKey });
    },

    async preferences(userId) {
      const rows = await jobDb
        .select()
        .from(notificationPreferences)
        .where(eq(notificationPreferences.userId, userId))
        .limit(1);
      const row = rows[0];
      return row
        ? mergeNotificationPreferences({
            enabled: row.enabled,
            timeZone: 'Europe/Paris',
            quietHoursStartMinute: row.quietHoursStartMinute ?? undefined,
            quietHoursEndMinute: row.quietHoursEndMinute ?? undefined,
            mutedOnWeekends: row.mutedOnWeekends,
            mutedOnHolidays: row.mutedOnHolidays,
            minimumSeverity: row.minimumSeverity,
            dailyCap: row.dailyCap,
            categories: row.categories,
            updatedAt: row.updatedAt.toISOString(),
          })
        : null;
    },
  };
}

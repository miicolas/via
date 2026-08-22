import { redis } from '../redis';
import { and, eq, gt, isNull, or } from 'drizzle-orm';
import { jobDb, notificationMutes, notificationPreferences } from '@via/db';
import { getDisruptionsSnapshot } from '../routers/lines/disruptions/snapshot';
import { notificationDelivery } from './index';
import {
  NOTIFICATION_ALERTS_ENABLED,
  NOTIFICATION_ALERT_POLL_SECONDS,
  NOTIFICATION_DISPATCH_POLL_SECONDS,
  NOTIFICATION_INBOX_RETENTION_DAYS,
  NOTIFICATION_MATERIALIZE_POLL_SECONDS,
  NOTIFICATION_OCCURRENCE_RETENTION_DAYS,
  NOTIFICATION_OCCURRENCE_BATCH,
  NOTIFICATION_SCHEDULER_ENABLED,
} from './config';
import { NotificationAlertMonitor } from './alert-monitor';
import { createDatabaseNotificationAlertSubscriptionStore } from './alert-subscription-store';
import { createDatabaseNotificationDispatcher } from './dispatcher';
import { createDatabaseNotificationInboxStore } from './inbox-store';
import { createRedisNotificationLineStateStore } from './line-state-store';
import { createDatabaseNotificationMaterializationStore, NotificationMaterializer } from './materializer';
import { createDatabaseNotificationOccurrenceStore } from './occurrence-store';
import { startNotificationDisruptionMonitor, stopNotificationDisruptionMonitor } from './monitor';

const SHARD_COUNT = 64;
const ELECTION_TTL_SECONDS = 60;

let timers: ReturnType<typeof setInterval>[] = [];

/** Starts all optional loops. Redis election keeps the process safe at N replicas. */
export function startNotificationRuntime() {
  if (process.env.NODE_ENV === 'test') return;
  // The existing journey monitor keeps its own coherence protocol and is not
  // folded into the generic occurrence dispatcher.
  startNotificationDisruptionMonitor();
  if (NOTIFICATION_SCHEDULER_ENABLED) startSchedulerLoops();
  if (NOTIFICATION_ALERTS_ENABLED) startAlertLoop();
}

export function stopNotificationRuntime() {
  timers.forEach(clearInterval);
  timers = [];
  stopNotificationDisruptionMonitor();
}

function startSchedulerLoops() {
  const materializer = new NotificationMaterializer({
    store: createDatabaseNotificationMaterializationStore(),
  });
  const dispatcher = createDatabaseNotificationDispatcher(notificationDelivery, redis);
  const occurrences = createDatabaseNotificationOccurrenceStore();
  const inbox = createDatabaseNotificationInboxStore(jobDb);

  const materialize = async () => {
    const cycle = Math.floor(Date.now() / (NOTIFICATION_MATERIALIZE_POLL_SECONDS * 1_000));
    for (let shard = 0; shard < SHARD_COUNT; shard += 1) {
      const key = `notifications:materialize:${cycle}:${shard}`;
      if (await redis.set(key, '1', { nx: true, ex: ELECTION_TTL_SECONDS })) {
        await materializer.pollOnce({ index: shard, count: SHARD_COUNT });
        if (shard === 0) {
          const now = new Date();
          await occurrences.purgeTerminal?.(
            new Date(now.getTime() - NOTIFICATION_OCCURRENCE_RETENTION_DAYS * 86_400_000),
            NOTIFICATION_OCCURRENCE_BATCH,
          );
          await inbox.purge?.(
            new Date(now.getTime() - NOTIFICATION_INBOX_RETENTION_DAYS * 86_400_000),
            NOTIFICATION_OCCURRENCE_BATCH,
          );
        }
      }
    }
  };
  const dispatch = async () => {
    const cycle = Math.floor(Date.now() / (NOTIFICATION_DISPATCH_POLL_SECONDS * 1_000));
    for (let shard = 0; shard < SHARD_COUNT; shard += 1) {
      const key = `notifications:dispatch:${cycle}:${shard}`;
      if (await redis.set(key, '1', { nx: true, ex: ELECTION_TTL_SECONDS })) {
        await dispatcher.pollOnce(shard, { reap: shard === 0 });
      }
    }
  };
  void materialize().catch((error) => console.error('[notifications] materializer failed', error));
  void dispatch().catch((error) => console.error('[notifications] dispatcher failed', error));
  timers.push(
    setInterval(() => void materialize().catch((error) => console.error('[notifications] materializer failed', error)), NOTIFICATION_MATERIALIZE_POLL_SECONDS * 1_000),
    setInterval(() => void dispatch().catch((error) => console.error('[notifications] dispatcher failed', error)), NOTIFICATION_DISPATCH_POLL_SECONDS * 1_000),
  );
}

function startAlertLoop() {
  const inbox = createDatabaseNotificationInboxStore(jobDb);
  const monitor = new NotificationAlertMonitor({
    redis,
    subscriptions: createDatabaseNotificationAlertSubscriptionStore(),
    lineState: createRedisNotificationLineStateStore(redis),
    inbox,
    delivery: notificationDelivery,
    snapshot: (now) => getDisruptionsSnapshot(redis, now),
    preferences: async (userId) => {
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
    muted: async (userId, category, topicId) => {
      const rows = await jobDb
        .select({ key: notificationMutes.key })
        .from(notificationMutes)
        .where(
          and(
            eq(notificationMutes.userId, userId),
            or(
              and(eq(notificationMutes.scope, 'category'), eq(notificationMutes.key, category)),
              and(eq(notificationMutes.scope, 'topic'), eq(notificationMutes.key, topicId)),
            ),
            or(isNull(notificationMutes.mutedUntil), gt(notificationMutes.mutedUntil, new Date())),
          ),
        )
        .limit(1);
      return rows.length > 0;
    },
    cycleMilliseconds: NOTIFICATION_ALERT_POLL_SECONDS * 1_000,
  });
  const poll = () => void monitor.pollOnce().catch((error) => console.error('[notifications] alert monitor failed', error));
  poll();
  timers.push(setInterval(poll, NOTIFICATION_ALERT_POLL_SECONDS * 1_000));
}

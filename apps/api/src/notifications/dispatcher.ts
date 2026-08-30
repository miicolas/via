import { jobDb } from '@via/db';
import type { NotificationDropReason } from '@via/contract';

import { getDisruptionsSnapshot, type DisruptionsSnapshot } from '../routers/lines/disruptions/snapshot';
import type { NormalizedDisruption } from '../routers/lines/disruptions/parse';
import type { RedisClient } from '../redis';
import { NotificationCycle } from './cycle';
import { NotificationDeliveryError, type NotificationDelivery } from './delivery';
import { createDatabaseNotificationInboxStore, type NotificationInboxStore } from './inbox-store';
import { createDatabaseNotificationOccurrenceStore, type ClaimedNotificationOccurrence, type NotificationOccurrenceStore } from './occurrence-store';
import {
  createDatabaseNotificationDispatcherScheduleStore,
  type NotificationDispatcherScheduleStore,
} from './schedule-store';
import { evaluateDelivery } from './policy';
import { fitDeviceNotification } from './payload';
import { renderNotification } from './render';

export const DELIVERY_CONCURRENCY = 50;
export const OCCURRENCE_LEASE_MINUTES = 2;

type OccurrencePayload = {
  category?: 'journey' | 'commute' | 'line' | 'station' | 'digest' | 'recommendation';
  scheduleId?: string;
  scheduleRevision?: number;
  label?: string;
  title?: string;
  body?: string;
  deepLink?: string;
  routeIds?: string[];
  lineName?: string;
  stationName?: string;
  severity?: 'attention' | 'disrupted' | 'suspended';
  topicKind?: 'line' | 'station';
  topicId?: string;
  empty?: boolean;
  event?: 'disruption' | 'restored' | 'digest' | 'recommendation' | 'reminder';
  [key: string]: unknown;
};

export type { NotificationDispatcherScheduleStore } from './schedule-store';

export class NotificationDispatcher {
  /**
   * The dispatcher's cycle claims work through the database (`claimDue`), not
   * a redis key: the claim itself returns the occurrence rows. The cycle only
   * owns the poll guard and the delivery fan-out waves.
   */
  private readonly cycle: NotificationCycle;

  constructor(
    private readonly options: {
      occurrences: NotificationOccurrenceStore;
      inbox: NotificationInboxStore;
      delivery: NotificationDelivery;
      schedules: NotificationDispatcherScheduleStore;
      snapshot?: (now: Date) => Promise<DisruptionsSnapshot | null>;
      redis?: RedisClient;
      now?: () => Date;
      staleMinutes?: number;
    },
  ) {
    this.cycle = new NotificationCycle({
      concurrency: DELIVERY_CONCURRENCY,
      now: options.now,
    });
  }

  async pollOnce(shard: number, options: { reap?: boolean } = {}): Promise<number> {
    return this.cycle.poll(0, async ({ now }) => {
      if (options.reap !== false) {
        await this.options.occurrences.reapExpired(200, now);
      }
      const claims = await this.options.occurrences.claimDue(200, shard);
      if (claims.length === 0) return 0;
      const snapshot = this.options.snapshot
        ? await this.options.snapshot(now)
        : await getDisruptionsSnapshot(
            this.options.redis ?? (await import('../redis')).redis,
            now,
          );
      await this.cycle.forEachWave(claims, (batch) =>
        Promise.all(batch.map((claim) => this.dispatchClaim(claim, snapshot, now))),
      );
      return claims.length;
    });
  }

  private async dispatchClaim(
    occurrence: ClaimedNotificationOccurrence,
    snapshot: DisruptionsSnapshot | null,
    now: Date,
  ) {
    const payload = occurrence.payload as OccurrencePayload;
    const category = payload.category ?? occurrence.category;
    const schedule = occurrence.scheduleId
      ? await this.options.schedules.schedule(occurrence.scheduleId)
      : undefined;
    const stale = now.getTime() > occurrence.dueAt.getTime() + (this.options.staleMinutes ?? 10) * 60_000;
    const revisionObsolete = Boolean(
      schedule &&
        occurrence.scheduleRevision !== schedule.revision,
    );
    const paused = Boolean(schedule?.pausedUntil && Date.parse(schedule.pausedUntil) > now.getTime());

    const matchingDisruptions = this.disruptionsFor(payload, snapshot);
    const disruption = matchingDisruptions[0];
    const candidate = renderNotification({
      category,
      severity: disruption?.severity ?? payload.severity,
      badge: occurrence.badge + 1,
      title: payload.title ?? (disruption?.title ? disruption.title : undefined),
      body: payload.body ?? disruption?.message,
      label: payload.label,
      lineName: payload.lineName ?? disruption?.routeIds[0],
      stationName: payload.stationName,
      event: payload.event,
      deepLink: payload.deepLink,
      topicKind: payload.topicKind,
      topicId: payload.topicId,
      data: {
        occurrenceId: occurrence.id,
        ...(schedule ? { scheduleId: schedule.id } : {}),
      },
    });
    const notification = fitDeviceNotification({
      ...candidate,
      collapseId: `via.occurrence.${occurrence.id}`,
    });

    const preferences = await this.options.schedules.preferences(occurrence.userId);
    const muted = await this.options.schedules.muted(
      occurrence.userId,
      category,
      payload.topicId,
    );
    const result = evaluateDelivery({
      preferences,
      category,
      severity: disruption?.severity ?? payload.severity,
      at: now,
      sentToday: occurrence.sentToday,
      muted,
      stale: stale || revisionObsolete || paused,
      hasSignal: category === 'commute' ? matchingDisruptions.length > 0 : undefined,
      empty: payload.empty,
      inDeclaredWindow: true,
    });

    if (!result.send) {
      await this.writeInbox(occurrence, notification, result.reason);
      await this.options.occurrences.finish([occurrence.id], 'dropped', result.reason);
      return;
    }

    // The inbox is durable before APNs. If the process dies after this point,
    // the reaper can safely retry the push and the occurrence collapse id hides
    // an at-least-once duplicate on the device.
    await this.writeInbox(occurrence, notification);
    try {
      if (!this.options.delivery.sendToUser) {
        throw new Error('Notification delivery has no user fan-out implementation.');
      }
      await this.options.delivery.sendToUser(occurrence.userId, {
        ...notification,
        interruptionLevel: result.interruptionLevel,
      });
      await this.options.occurrences.finish([occurrence.id], 'sent');
    } catch (error) {
      const failure = error instanceof NotificationDeliveryError
        ? error
        : new NotificationDeliveryError(error);
      if (!failure.retryable && !failure.invalidToken) {
        await this.options.occurrences.finish([occurrence.id], 'dropped', 'stale');
      }
      console.error('[notifications] occurrence delivery failed', { occurrenceId: occurrence.id, error });
    }
  }

  private disruptionsFor(payload: OccurrencePayload, snapshot: DisruptionsSnapshot | null): NormalizedDisruption[] {
    if (!snapshot || !payload.routeIds || payload.routeIds.length === 0) return [];
    const routeIds = new Set(payload.routeIds);
    return snapshot.disruptions.filter((disruption) =>
      disruption.routeIds.some((routeId) => routeIds.has(routeId)),
    );
  }

  private async writeInbox(
    occurrence: ClaimedNotificationOccurrence,
    notification: ReturnType<typeof renderNotification>,
    dropReason?: NotificationDropReason,
  ) {
    const data = notification.data ?? {};
    await this.options.inbox.insert({
      id: `occurrence:${occurrence.id}`,
      userId: occurrence.userId,
      occurrenceId: occurrence.id,
      category: occurrence.category,
      title: notification.title,
      body: notification.body,
      deepLink: typeof data.deepLink === 'string' ? data.deepLink : null,
      topicKind: typeof data.topicKind === 'string' && (data.topicKind === 'line' || data.topicKind === 'station')
        ? data.topicKind
        : null,
      topicId: typeof data.topicId === 'string' ? data.topicId : null,
      severity: typeof data.severity === 'string' ? data.severity as 'attention' | 'disrupted' | 'suspended' : null,
      dropReason: dropReason ?? null,
    });
  }
}

export function createDatabaseNotificationDispatcher(
  delivery: NotificationDelivery,
  redis?: RedisClient,
): NotificationDispatcher {
  return new NotificationDispatcher({
    occurrences: createDatabaseNotificationOccurrenceStore(),
    inbox: createDatabaseNotificationInboxStore(jobDb),
    delivery,
    redis,
    schedules: createDatabaseNotificationDispatcherScheduleStore(),
  });
}

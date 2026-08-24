import { parisDay, parisWeekday } from '../time/paris';
import type { DisruptionsSnapshot } from '../routers/lines/disruptions/snapshot';
import type { NormalizedDisruption } from '../routers/lines/disruptions/parse';
import type { RedisClient } from '../redis';
import type { NotificationDelivery } from './delivery';
import type { NotificationInboxStore } from './inbox-store';
import { impactedStopIds } from './impacted-stop-ids';
import type { NotificationLineStateStore } from './line-state-store';
import { evaluateDelivery } from './policy';
import { fitDeviceNotification, stableIdentifierHash } from './payload';
import { renderNotification } from './render';
import type { NotificationAlertSubscriptionStore } from './alert-subscription-store';
import { disruptionVersion } from './disruption-monitor';
import type { NotificationAlertSubscription } from '@via/contract';

const ALERT_CLAIM_TTL_SECONDS = 3 * 24 * 60 * 60;

export class NotificationAlertMonitor {
  private isPolling = false;

  constructor(
    private readonly options: {
      redis: RedisClient;
      subscriptions: NotificationAlertSubscriptionStore;
      lineState: NotificationLineStateStore;
      inbox: NotificationInboxStore;
      delivery: NotificationDelivery;
      snapshot: (now: Date) => Promise<DisruptionsSnapshot | null>;
      preferences: (userId: string) => Promise<Parameters<typeof evaluateDelivery>[0]['preferences']>;
      muted?: (userId: string, category: 'line' | 'station', topicId: string) => Promise<boolean>;
      now?: () => Date;
      cycleMilliseconds?: number;
    },
  ) {}

  async pollOnce(): Promise<number> {
    if (this.isPolling) return 0;
    this.isPolling = true;
    const now = this.options.now?.() ?? new Date();
    const cycle = Math.floor(now.getTime() / (this.options.cycleMilliseconds ?? 120_000));
    let delivered = 0;
    try {
      const [allLineSubscriptions, allStationSubscriptions] = await Promise.all([
        this.options.subscriptions.listActive('line'),
        this.options.subscriptions.listActive('station'),
      ]);
      const lineSubscriptions = allLineSubscriptions.filter((subscription) =>
        isAlertWindowActive(subscription, now)
      );
      const stationSubscriptions = allStationSubscriptions.filter((subscription) =>
        isAlertWindowActive(subscription, now)
      );
      if (lineSubscriptions.length === 0 && stationSubscriptions.length === 0) return 0;

      const snapshot = await this.options.snapshot(now);
      if (!snapshot) return 0;
      const routes = new Set([
        ...snapshot.disruptions.flatMap((disruption) => disruption.routeIds),
        ...lineSubscriptions.map((subscription) => subscription.topicId),
      ]);
      for (const routeId of routes) {
        const claimed = await this.options.redis.set(
          `notifications:alert-cycle:${cycle}:line:${routeId}`,
          '1',
          { nx: true, ex: ALERT_CLAIM_TTL_SECONDS },
        );
        if (claimed === null) continue;
        const current = snapshot.disruptions.filter((disruption) => disruption.routeIds.includes(routeId));
        const previous = await this.options.lineState.get(routeId);
        const currentIDs = new Set(current.map((disruption) => disruption.id));
        const appeared = current.filter((disruption) => !previous.has(disruption.id));
        const restored = [...previous]
          .filter((id) => !currentIDs.has(id))
          .map((id) => ({ id, routeIds: [routeId] }));
        const subscriptions = lineSubscriptions.filter(
          (subscription) => subscription.topicId === routeId
        );
        for (const subscription of subscriptions) {
          for (const disruption of appeared) {
            if (!matchesAlert(subscription, now, disruption.severity)) continue;
            if (await this.deliver(subscription, disruption, 'disruption', now)) delivered += 1;
          }
          for (const disruption of restored) {
            if (!matchesAlert(subscription, now, 'attention')) continue;
            if (await this.deliver(subscription, disruption, 'restored', now)) delivered += 1;
          }
        }
        await this.options.lineState.set(routeId, currentIDs);
      }

      const stations = new Map<string, NormalizedDisruption[]>();
      for (const disruption of snapshot.disruptions) {
        const stops = await impactedStopIds(disruption.impactedSections);
        for (const stopId of stops) {
          const bucket = stations.get(stopId) ?? [];
          bucket.push(disruption);
          stations.set(stopId, bucket);
        }
      }
      const stationIDs = new Set([
        ...stations.keys(),
        ...stationSubscriptions.map((subscription) => subscription.topicId),
      ]);
      for (const stationID of stationIDs) {
        const disruptions = stations.get(stationID) ?? [];
        const currentIDs = new Set(disruptions.map((disruption) => disruption.id));
        const stateKey = `station:${stationID}`;
        const previous = await this.options.lineState.get(stateKey);
        const appeared = disruptions.filter((disruption) => !previous.has(disruption.id));
        const restored = [...previous]
          .filter((id) => !currentIDs.has(id))
          .map((id) => ({ id, routeIds: [stationID] }));
        const claimed = await this.options.redis.set(
          `notifications:alert-cycle:${cycle}:station:${stationID}`,
          '1',
          { nx: true, ex: ALERT_CLAIM_TTL_SECONDS },
        );
        if (claimed === null) continue;
        const subscriptions = stationSubscriptions.filter(
          (subscription) => subscription.topicId === stationID
        );
        for (const subscription of subscriptions) {
          for (const disruption of appeared) {
            if (!matchesAlert(subscription, now, disruption.severity)) continue;
            if (await this.deliver(subscription, disruption, 'disruption', now)) delivered += 1;
          }
          for (const disruption of restored) {
            if (!matchesAlert(subscription, now, 'attention')) continue;
            if (await this.deliver(subscription, disruption, 'restored', now)) delivered += 1;
          }
        }
        await this.options.lineState.set(stateKey, currentIDs);
      }
      return delivered;
    } finally {
      this.isPolling = false;
    }
  }

  private async deliver(
    subscription: NotificationAlertSubscription & { userId: string },
    disruption: Pick<NormalizedDisruption, 'id' | 'routeIds' | 'title' | 'message'> & {
      severity?: NormalizedDisruption['severity'];
    },
    event: 'disruption' | 'restored',
    now: Date,
  ): Promise<boolean> {
    const version = disruption.severity !== undefined
      ? disruptionVersion(disruption as NormalizedDisruption)
      : stableIdentifierHash(`${event}:${disruption.id}`);
    const claimKey = `notifications:alert:${subscription.userId}:${subscription.id}:${disruption.id}:${event}:${version}`;
    const claimed = await this.options.redis.set(claimKey, '1', {
      nx: true,
      ex: ALERT_CLAIM_TTL_SECONDS,
    });
    if (claimed === null) return false;

    const lineName = disruption.routeIds[0];
    const notification = fitDeviceNotification({
      ...renderNotification({
        category: subscription.topicKind,
        severity: disruption.severity ?? 'attention',
        badge: (await this.options.inbox.unreadCount(subscription.userId)) + 1,
        title: disruption.title,
        body: disruption.message,
        lineName: subscription.topicKind === 'line' ? lineName : undefined,
        stationName: subscription.topicKind === 'station' ? subscription.label : undefined,
        event,
        topicKind: subscription.topicKind,
        topicId: subscription.topicId,
        deepLink: subscription.topicKind === 'line'
          ? `via://line?routeId=${encodeURIComponent(subscription.topicId)}`
          : `via://station?stationId=${encodeURIComponent(subscription.topicId)}`,
        data: { alertSubscriptionId: subscription.id },
      }),
      collapseId: `via.alert.${stableIdentifierHash(claimKey)}`,
    });
    const severity = disruption.severity ?? 'attention';
    const decision = evaluateDelivery({
      preferences: await this.options.preferences(subscription.userId),
      category: subscription.topicKind,
      severity,
      at: now,
      sentToday: await this.options.inbox.sentToday?.(
        subscription.userId,
        now,
        subscription.topicKind,
      ),
      muted: await this.options.muted?.(
        subscription.userId,
        subscription.topicKind,
        subscription.topicId,
      ),
      inDeclaredWindow: true,
    });
    if (!decision.send) {
      await this.options.inbox.insert({
        id: claimKey,
        userId: subscription.userId,
        occurrenceId: null,
        category: subscription.topicKind,
        title: notification.title,
        body: notification.body,
        deepLink: typeof notification.data?.deepLink === 'string' ? notification.data.deepLink : null,
        topicKind: subscription.topicKind,
        topicId: subscription.topicId,
        severity,
        dropReason: decision.reason,
      });
      return false;
    }
    await this.options.inbox.insert({
      id: claimKey,
      userId: subscription.userId,
      occurrenceId: null,
      category: subscription.topicKind,
      title: notification.title,
      body: notification.body,
      deepLink: typeof notification.data?.deepLink === 'string' ? notification.data.deepLink : null,
      topicKind: subscription.topicKind,
      topicId: subscription.topicId,
      severity,
    });
    if (!this.options.delivery.sendToUser) return false;
    try {
      await this.options.delivery.sendToUser(subscription.userId, {
        ...notification,
        interruptionLevel: decision.interruptionLevel,
      });
      return true;
    } catch (error) {
      // The inbox insert is idempotent, while the stable claim key is safe to
      // release: a later cycle retries the push and APNs collapse-id keeps
      // the retry invisible if the first attempt actually arrived.
      await this.options.redis.del(claimKey).catch(() => undefined);
      console.error('[notifications] alert delivery failed', { claimKey, error });
      return false;
    }
  }
}

function matchesAlert(
  subscription: NotificationAlertSubscription,
  now: Date,
  severity: 'attention' | 'disrupted' | 'suspended',
): boolean {
  const ranks = { attention: 0, disrupted: 1, suspended: 2 };
  if (ranks[severity] < ranks[subscription.minimumSeverity]) return false;
  return isAlertWindowActive(subscription, now);
}

function isAlertWindowActive(
  subscription: NotificationAlertSubscription,
  now: Date,
): boolean {
  const weekday = parisWeekday(now);
  if (subscription.daysOfWeek.length > 0 && !subscription.daysOfWeek.includes(weekday)) return false;
  if (subscription.windows.length === 0) return true;
  const minute = Math.floor(parisDay(now).seconds / 60);
  return subscription.windows.some((window) =>
    window.startMinute < window.endMinute
      ? minute >= window.startMinute && minute < window.endMinute
      : minute >= window.startMinute || minute < window.endMinute,
  );
}

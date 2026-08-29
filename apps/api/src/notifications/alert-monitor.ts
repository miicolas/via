import { parisDay, parisWeekday } from '../time/paris';
import type { DisruptionsSnapshot } from '../routers/lines/disruptions/snapshot';
import type { NormalizedDisruption } from '../routers/lines/disruptions/parse';
import type { RedisClient } from '../redis';
import type { NotificationDelivery } from './delivery';
import type { NotificationInboxStore } from './inbox-store';
import { impactedStopIds } from './impacted-stop-ids';
import type {
  NotificationLineState,
  NotificationLineStateStore,
} from './line-state-store';
import { evaluateDelivery } from './policy';
import { fitDeviceNotification, stableIdentifierHash } from './payload';
import { renderNotification } from './render';
import type { NotificationAlertSubscriptionStore } from './alert-subscription-store';
import { disruptionVersion } from './disruption-monitor';
import type { NotificationAlertSubscription } from '@via/contract';

// A cycle claim only needs to outlive a slow poll and a scheduler retry. Keeping
// it for days creates millions of useless keys because the poll runs often.
const ALERT_CLAIM_TTL_SECONDS = 10 * 60;
const ALERT_CONTENT_DEDUP_TTL_SECONDS = 15 * 60;
const RESTORED_CONFIRMATION_CYCLES = 2;

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
        const subscriptions = lineSubscriptions.filter(
          (subscription) => subscription.topicId === routeId,
        );
        // Do not advance a route's global state just because another alert
        // caused us to load the snapshot. Otherwise an alert enabled later
        // sees an already-active disruption as old and never receives it.
        if (subscriptions.length === 0) continue;

        const claimed = await this.options.redis.set(
          `notifications:alert-cycle:${cycle}:line:${routeId}`,
          '1',
          { nx: true, ex: ALERT_CLAIM_TTL_SECONDS },
        );
        if (claimed === null) continue;
        const current = snapshot.disruptions.filter((disruption) => disruption.routeIds.includes(routeId));
        const previous = await this.options.lineState.get(routeId);
        const currentSubscriptionIds = new Set(subscriptions.map((subscription) => subscription.id));
        const newlyActiveSubscriptionIds = new Set(
          [...currentSubscriptionIds].filter((id) => !previous.subscriptionIds.has(id)),
        );
        const transition = advanceNotificationState(
          previous,
          current,
          routeId,
          currentSubscriptionIds,
        );
        for (const subscription of subscriptions) {
          const appeared = newlyActiveSubscriptionIds.has(subscription.id)
            ? current
            : transition.appeared;
          for (const disruption of appeared) {
            if (!matchesAlert(subscription, now, disruption.severity)) continue;
            if (await this.deliver(subscription, disruption, 'disruption', now)) delivered += 1;
          }
          for (const disruption of transition.restored) {
            if (!matchesAlert(subscription, now, 'attention')) continue;
            if (await this.deliver(subscription, disruption, 'restored', now)) delivered += 1;
          }
        }
        await this.options.lineState.set(routeId, transition.next);
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
        const subscriptions = stationSubscriptions.filter(
          (subscription) => subscription.topicId === stationID,
        );
        if (subscriptions.length === 0) continue;

        const disruptions = stations.get(stationID) ?? [];
        const stateKey = `station:${stationID}`;
        const claimed = await this.options.redis.set(
          `notifications:alert-cycle:${cycle}:station:${stationID}`,
          '1',
          { nx: true, ex: ALERT_CLAIM_TTL_SECONDS },
        );
        if (claimed === null) continue;
        const previous = await this.options.lineState.get(stateKey);
        const currentSubscriptionIds = new Set(subscriptions.map((subscription) => subscription.id));
        const newlyActiveSubscriptionIds = new Set(
          [...currentSubscriptionIds].filter((id) => !previous.subscriptionIds.has(id)),
        );
        const transition = advanceNotificationState(
          previous,
          disruptions,
          stationID,
          currentSubscriptionIds,
        );
        for (const subscription of subscriptions) {
          const appeared = newlyActiveSubscriptionIds.has(subscription.id)
            ? disruptions
            : transition.appeared;
          for (const disruption of appeared) {
            if (!matchesAlert(subscription, now, disruption.severity)) continue;
            if (await this.deliver(subscription, disruption, 'disruption', now)) delivered += 1;
          }
          for (const disruption of transition.restored) {
            if (!matchesAlert(subscription, now, 'attention')) continue;
            if (await this.deliver(subscription, disruption, 'restored', now)) delivered += 1;
          }
        }
        await this.options.lineState.set(stateKey, transition.next);
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
    const lineLabel = subscription.topicKind === 'line'
      ? subscription.label.trim()
      : undefined;
    const lineName = lineLabel?.replace(/^ligne\s+/i, '').trim() || lineLabel;
    const title = subscription.topicKind === 'line'
      ? event === 'restored'
        ? `Trafic rétabli · ${lineLabel}`
        : `Perturbation · ${lineLabel}`
      : disruption.title;
    const body = subscription.topicKind === 'line' && event === 'restored'
      ? `Le trafic est rétabli sur la ligne ${lineName}.`
      : disruption.message ?? disruption.title;
    const contentClaimKey = [
      'notifications:alert-content',
      subscription.userId,
      subscription.id,
      event,
      stableIdentifierHash(JSON.stringify({
        title: normalizeNotificationText(title),
        body: normalizeNotificationText(body),
      })),
    ].join(':');
    const claimed = await this.options.redis.set(claimKey, '1', {
      nx: true,
      ex: ALERT_CLAIM_TTL_SECONDS,
    });
    if (claimed === null) return false;

    const contentClaimed = await this.options.redis.set(contentClaimKey, '1', {
      nx: true,
      ex: ALERT_CONTENT_DEDUP_TTL_SECONDS,
    });
    if (contentClaimed === null) return false;

    const notification = fitDeviceNotification({
      ...renderNotification({
        category: subscription.topicKind,
        severity: disruption.severity ?? 'attention',
        badge: (await this.options.inbox.unreadCount(subscription.userId)) + 1,
        title,
        body,
        lineName,
        stationName: subscription.topicKind === 'station' ? subscription.label : undefined,
        event,
        topicKind: subscription.topicKind,
        topicId: subscription.topicId,
        deepLink: subscription.topicKind === 'line'
          ? `via://line?routeId=${encodeURIComponent(subscription.topicId)}`
          : `via://station?stationId=${encodeURIComponent(subscription.topicId)}`,
        data: {
          alertSubscriptionId: subscription.id,
          ...(lineLabel ? { lineName: lineLabel } : {}),
        },
      }),
      collapseId: `via.alert.${stableIdentifierHash(contentClaimKey)}`,
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
      console.info('[notifications] alert dropped', {
        category: subscription.topicKind,
        topicId: subscription.topicId,
        event,
        disruptionId: disruption.id,
        reason: decision.reason,
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
      console.info('[notifications] alert delivered', {
        category: subscription.topicKind,
        topicId: subscription.topicId,
        event,
        disruptionId: disruption.id,
      });
      return true;
    } catch (error) {
      // The inbox insert is idempotent. Release both claims so a later cycle
      // can retry; the content-based APNs collapse-id keeps a retry of the
      // same alert from creating a second pending notification.
      await Promise.all([
        this.options.redis.del(claimKey).catch(() => undefined),
        this.options.redis.del(contentClaimKey).catch(() => undefined),
      ]);
      console.error('[notifications] alert delivery failed', {
        category: subscription.topicKind,
        topicId: subscription.topicId,
        event,
        disruptionId: disruption.id,
        error,
      });
      return false;
    }
  }
}

type NotificationStateTransition = {
  appeared: NormalizedDisruption[];
  restored: Array<{ id: string; routeIds: string[] }>;
  next: NotificationLineState;
};

function advanceNotificationState(
  previous: NotificationLineState,
  current: NormalizedDisruption[],
  topicId: string,
  subscriptionIds: ReadonlySet<string>,
): NotificationStateTransition {
  const currentIDs = new Set(current.map((disruption) => disruption.id));
  const nextIDs = new Set(currentIDs);
  const missingCycles = new Map<string, number>();
  const restored: Array<{ id: string; routeIds: string[] }> = [];

  for (const id of previous.disruptionIds) {
    if (currentIDs.has(id)) continue;
    const cycles = (previous.missingCycles.get(id) ?? 0) + 1;
    if (cycles >= RESTORED_CONFIRMATION_CYCLES) {
      restored.push({ id, routeIds: [topicId] });
    } else {
      // Keep the disruption in the active state during the grace period so a
      // one-poll upstream gap cannot emit a false restoration or a duplicate
      // when the same disruption reappears.
      nextIDs.add(id);
      missingCycles.set(id, cycles);
    }
  }

  return {
    appeared: current.filter((disruption) => !previous.disruptionIds.has(disruption.id)),
    restored,
    next: { disruptionIds: nextIDs, subscriptionIds, missingCycles },
  };
}

function normalizeNotificationText(value: string | undefined): string {
  return (value ?? '').normalize('NFKC').replace(/\s+/gu, ' ').trim().toLowerCase();
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

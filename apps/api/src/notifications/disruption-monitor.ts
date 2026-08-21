import { getDisruptionsSnapshot } from '../routers/lines/disruptions/snapshot';
import type { DisruptionsSnapshot } from '../routers/lines/disruptions/snapshot';
import type { NormalizedDisruption } from '../routers/lines/disruptions/parse';
import type { RedisClient } from '../redis';
import type { NotificationDelivery } from './delivery';
import type { NotificationJourneySubscription, NotificationJourneySubscriptionStore } from './journey-subscriptions';

const LOCK_KEY = 'notifications:disruption-monitor:lock';
const LOCK_TTL_SECONDS = 90;
const DEDUP_TTL_SECONDS = 60 * 60 * 24 * 3;

export type DisruptionSnapshotLoader = (
  now: Date,
) => Promise<DisruptionsSnapshot | null>;

export function journeyDisruptionMatches(
  subscription: Pick<NotificationJourneySubscription, 'routeIds' | 'startsAt' | 'endsAt'>,
  disruption: Pick<NormalizedDisruption, 'routeIds' | 'periods'>,
  now: Date,
): boolean {
  const nowSeconds = Math.floor(now.getTime() / 1_000);
  const inJourneyWindow =
    now >= subscription.startsAt && now <= subscription.endsAt;
  const touchesJourney = disruption.routeIds.some((routeId) =>
    subscription.routeIds.includes(routeId),
  );
  const inDisruptionWindow = disruption.periods.some(
    (period) => nowSeconds >= period.beginsAt && nowSeconds <= period.endsAt,
  );
  return inJourneyWindow && touchesJourney && inDisruptionWindow;
}

export function disruptionVersion(disruption: NormalizedDisruption): string {
  const explicitVersion = disruption.updatedAt;
  if (explicitVersion !== undefined) {
    return `${explicitVersion}:${disruption.severity}`;
  }

  const value = JSON.stringify({
    severity: disruption.severity,
    cause: disruption.cause,
    title: disruption.title,
    message: disruption.message,
    routeIds: disruption.routeIds,
    periods: disruption.periods,
  });
  let hash = 2166136261;
  for (const character of value) {
    hash ^= character.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return `${disruption.severity}:${(hash >>> 0).toString(16)}`;
}

export function journeyDisruptionNotification(
  subscription: Pick<NotificationJourneySubscription, 'journeyId'>,
  disruption: NormalizedDisruption,
) {
  const deepLink = `via://journey?journeyId=${encodeURIComponent(subscription.journeyId)}&mode=active`;
  const line = disruption.routeIds[0] ?? 'une ligne de votre trajet';
  const collapseId = `via.journey.${subscription.journeyId}.disruption.${disruption.id}`
    .replace(/[^A-Za-z0-9_.-]/g, '_')
    .slice(0, 64);
  return {
    title: disruption.title ?? `Perturbation sur ${line}`,
    body:
      disruption.message ??
      `Une perturbation touche ${line} pendant votre trajet.`,
    sound: 'default',
    collapseId,
    data: {
      type: 'journey',
      event: 'disruption',
      journeyId: subscription.journeyId,
      url: deepLink,
      deepLink,
    },
  } as const;
}

export class NotificationDisruptionMonitor {
  private isPolling = false;

  constructor(
    private readonly options: {
      redis: RedisClient;
      subscriptions: NotificationJourneySubscriptionStore;
      delivery: NotificationDelivery;
      snapshot?: DisruptionSnapshotLoader;
      now?: () => Date;
    },
  ) {}

  async pollOnce(): Promise<void> {
    if (this.isPolling) return;
    this.isPolling = true;

    let lockAcquired = false;
    const lockValue = crypto.randomUUID();
    try {
      const lock = await this.options.redis.set(
        LOCK_KEY,
        JSON.stringify(lockValue),
        { nx: true, ex: LOCK_TTL_SECONDS },
      );
      if (lock === null) return;
      lockAcquired = true;

      const now = this.options.now?.() ?? new Date();
      await this.options.subscriptions.deleteExpired(now);
      const subscriptions = await this.options.subscriptions.listActive(now);
      if (subscriptions.length === 0) return;

      const snapshot = await (this.options.snapshot ?? ((date) =>
        getDisruptionsSnapshot(this.options.redis, date)))(now);
      if (!snapshot) return;

      await Promise.all(
        subscriptions.map((subscription) =>
          this.notifySubscription(subscription, snapshot.disruptions, now),
        ),
      );
    } catch (error) {
      console.error('[notifications] disruption monitor failed', error);
    } finally {
      if (lockAcquired) {
        const currentLock = await this.options.redis
          .get<string>(LOCK_KEY)
          .catch(() => null);
        if (currentLock === lockValue) {
          await this.options.redis.del(LOCK_KEY).catch(() => undefined);
        }
      }
      this.isPolling = false;
    }
  }

  private async notifySubscription(
    subscription: NotificationJourneySubscription,
    disruptions: NormalizedDisruption[],
    now: Date,
  ) {
    const matching = disruptions.filter((disruption) =>
      journeyDisruptionMatches(subscription, disruption, now),
    );

    for (const disruption of matching) {
      const version = disruptionVersion(disruption);
      const dedupKey =
        `notifications:disruption:${subscription.userId}:` +
        `${subscription.journeyId}:${disruption.id}:${version}`;
      const claimed = await this.options.redis.set(dedupKey, '1', {
        nx: true,
        ex: DEDUP_TTL_SECONDS,
      });
      if (claimed === null) continue;

      try {
        const report = await this.options.delivery.sendToUser(
          subscription.userId,
          journeyDisruptionNotification(subscription, disruption),
        );
        if (report.sent === 0) {
          await this.options.redis.del(dedupKey).catch(() => undefined);
        }
      } catch (error) {
        await this.options.redis.del(dedupKey).catch(() => undefined);
        console.error('[notifications] disruption APNs delivery failed', error);
      }
    }
  }
}

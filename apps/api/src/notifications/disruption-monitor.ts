import { getDisruptionsSnapshot } from "../routers/lines/disruptions/snapshot";
import type { DisruptionsSnapshot } from "../routers/lines/disruptions/snapshot";
import type { NormalizedDisruption } from "../routers/lines/disruptions/parse";
import type { RedisClient } from "../redis";
import type { NotificationDelivery } from "./delivery";
import type {
  NotificationJourneyRecipient,
  NotificationJourneySubscription,
  NotificationJourneySubscriptionStore,
} from "./journey-subscriptions";

const LOCK_KEY = "notifications:disruption-monitor:lock";
const LOCK_TTL_SECONDS = 90;
const LOCK_HEARTBEAT_MILLISECONDS = (LOCK_TTL_SECONDS * 1_000) / 3;
const DEDUP_TTL_SECONDS = 60 * 60 * 24 * 3;
const SUBSCRIPTION_BATCH_SIZE = 250;
const DELIVERY_CONCURRENCY = 10;

export type DisruptionSnapshotLoader = (
  now: Date,
) => Promise<DisruptionsSnapshot | null>;

type DisruptionsByRoute = ReadonlyMap<string, readonly NormalizedDisruption[]>;

export function journeyDisruptionMatches(
  subscription: Pick<
    NotificationJourneySubscription,
    "routeIds" | "startsAt" | "endsAt"
  >,
  disruption: Pick<NormalizedDisruption, "routeIds" | "periods">,
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
  subscription: Pick<NotificationJourneySubscription, "journeyId">,
  disruption: NormalizedDisruption,
) {
  const deepLink = `via://journey?journeyId=${encodeURIComponent(subscription.journeyId)}&mode=active`;
  const line = disruption.routeIds[0] ?? "une ligne de votre trajet";
  const collapseId =
    `via.journey.${subscription.journeyId}.disruption.${disruption.id}`
      .replace(/[^A-Za-z0-9_.-]/g, "_")
      .slice(0, 64);
  return {
    title: disruption.title ?? `Perturbation sur ${line}`,
    body:
      disruption.message ??
      `Une perturbation touche ${line} pendant votre trajet.`,
    sound: "default",
    collapseId,
    data: {
      type: "journey",
      event: "disruption",
      journeyId: subscription.journeyId,
      url: deepLink,
      deepLink,
    },
  } as const;
}

function indexDisruptionsByRoute(
  disruptions: NormalizedDisruption[],
): DisruptionsByRoute {
  const byRoute = new Map<string, NormalizedDisruption[]>();
  for (const disruption of disruptions) {
    for (const routeId of disruption.routeIds) {
      const bucket = byRoute.get(routeId);
      if (bucket) bucket.push(disruption);
      else byRoute.set(routeId, [disruption]);
    }
  }
  return byRoute;
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
    let lockLost = false;
    let heartbeat: ReturnType<typeof setInterval> | undefined;
    let renewal = Promise.resolve();
    const lockValue = crypto.randomUUID();
    const serializedLockValue = JSON.stringify(lockValue);
    try {
      const lock = await this.options.redis.set(LOCK_KEY, serializedLockValue, {
        nx: true,
        ex: LOCK_TTL_SECONDS,
      });
      if (lock === null) return;
      lockAcquired = true;
      heartbeat = setInterval(() => {
        renewal = renewal
          .then(async () => {
            const renewed = await this.options.redis.compareAndExpire(
              LOCK_KEY,
              serializedLockValue,
              LOCK_TTL_SECONDS,
            );
            if (!renewed) lockLost = true;
          })
          .catch((error) => {
            lockLost = true;
            console.error(
              "[notifications] disruption monitor lock renewal failed",
              error,
            );
          });
      }, LOCK_HEARTBEAT_MILLISECONDS);

      const now = this.options.now?.() ?? new Date();
      await this.options.subscriptions.deleteExpired(now);
      const snapshot = await (
        this.options.snapshot ??
        ((date) => getDisruptionsSnapshot(this.options.redis, date))
      )(now);
      if (!snapshot) return;
      const disruptionsByRoute = indexDisruptionsByRoute(snapshot.disruptions);

      let afterInstallationId: string | undefined;
      do {
        const recipients = await this.options.subscriptions.listActiveBatch(
          now,
          afterInstallationId,
          SUBSCRIPTION_BATCH_SIZE,
        );
        if (recipients.length === 0) break;

        for (
          let start = 0;
          start < recipients.length;
          start += DELIVERY_CONCURRENCY
        ) {
          if (lockLost) return;
          await Promise.all(
            recipients
              .slice(start, start + DELIVERY_CONCURRENCY)
              .map((recipient) =>
                this.notifySubscription(recipient, disruptionsByRoute, now),
              ),
          );
        }

        afterInstallationId = recipients.at(-1)?.installationId;
        if (recipients.length < SUBSCRIPTION_BATCH_SIZE) break;
        const renewed = await this.options.redis.compareAndExpire(
          LOCK_KEY,
          serializedLockValue,
          LOCK_TTL_SECONDS,
        );
        if (!renewed) return;
      } while (afterInstallationId);
    } catch (error) {
      console.error("[notifications] disruption monitor failed", error);
    } finally {
      if (heartbeat) clearInterval(heartbeat);
      await renewal;
      if (lockAcquired) {
        await this.options.redis
          .compareAndDelete(LOCK_KEY, serializedLockValue)
          .catch(() => false);
      }
      this.isPolling = false;
    }
  }

  private async notifySubscription(
    subscription: NotificationJourneyRecipient,
    disruptionsByRoute: DisruptionsByRoute,
    now: Date,
  ) {
    const candidates = new Map<string, NormalizedDisruption>();
    for (const routeId of subscription.routeIds) {
      for (const disruption of disruptionsByRoute.get(routeId) ?? []) {
        candidates.set(disruption.id, disruption);
      }
    }
    const matching = [...candidates.values()].filter((disruption) =>
      journeyDisruptionMatches(subscription, disruption, now),
    );

    for (const disruption of matching) {
      const version = disruptionVersion(disruption);
      const dedupKey =
        `notifications:disruption:${subscription.installationId}:` +
        `${subscription.journeyId}:${disruption.id}:${version}`;
      const claimed = await this.options.redis.set(dedupKey, "1", {
        nx: true,
        ex: DEDUP_TTL_SECONDS,
      });
      if (claimed === null) continue;

      try {
        const report = await this.options.delivery.sendToDevice(
          subscription,
          journeyDisruptionNotification(subscription, disruption),
        );
        if (report.sent === 0) {
          await this.options.redis.del(dedupKey).catch(() => undefined);
        }
      } catch (error) {
        await this.options.redis.del(dedupKey).catch(() => undefined);
        console.error("[notifications] disruption APNs delivery failed", error);
      }
    }
  }
}

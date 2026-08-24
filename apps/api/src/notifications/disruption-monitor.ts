import { NOTIFICATION_DELIVERY_SHARD_COUNT } from "@via/db";

import { getDisruptionsSnapshot } from "../routers/lines/disruptions/snapshot";
import type { DisruptionsSnapshot } from "../routers/lines/disruptions/snapshot";
import type { NormalizedDisruption } from "../routers/lines/disruptions/parse";
import type { RedisClient } from "../redis";
import {
  NotificationDeliveryError,
  type NotificationDelivery,
} from "./delivery";
import {
  fitDeviceNotification,
  notificationTextEncoder as encoder,
  stableIdentifierHash,
  truncateUTF8,
} from "./payload";
import type { DeviceNotification } from "./payload";
import type {
  NotificationJourneyRecipient,
  NotificationJourneySubscription,
  NotificationJourneySubscriptionStore,
} from "./journey-subscriptions";
import {
  notificationSubscriptionVersion,
  notificationSubscriptionVersionKey,
  notificationSubscriptionVersionTTLSeconds,
  notificationSubscriptionLeaseKey,
  setNotificationSubscriptionVersionWhenIdle,
} from "./journey-subscriptions";

const DEDUP_TTL_SECONDS = 60 * 60 * 24 * 3;
const DELIVERY_CLAIM_TTL_SECONDS = 5 * 60;
// Covers provider-token generation plus both bounded APNs attempts (2 × 15 s)
// with enough margin for response parsing and event-loop stalls.
const DELIVERY_LEASE_TTL_SECONDS = 60;
const DELIVERY_CIRCUIT_KEY = "notifications:apns:circuit";
const DELIVERY_CIRCUIT_TTL_SECONDS = 60;
const SUBSCRIPTION_BATCH_SIZE = 250;
const DELIVERY_CONCURRENCY = 50;
const EXPIRATION_CLEANUP_BATCH_SIZE = 500;
const EXPIRATION_CLEANUP_BUDGET_MILLISECONDS = 2_000;
const SHARD_CYCLE_MILLISECONDS = 2 * 60 * 1_000;
const SHARD_CLAIM_TTL_SECONDS = 10 * 60;

export type DisruptionSnapshotLoader = (
  now: Date,
) => Promise<DisruptionsSnapshot | null>;

type DisruptionsByRoute = ReadonlyMap<string, readonly NormalizedDisruption[]>;

type DeliveryClaim = {
  subscription: NotificationJourneyRecipient;
  disruption: NormalizedDisruption;
  /// Built on demand: most claims are rejected as duplicates before delivery,
  /// and encoding the payload costs a JSON serialize plus five UTF-8 passes.
  notification: () => ReturnType<typeof journeyDisruptionNotification>;
  dedupKey: string;
  claimKey: string;
  claimValue: string;
  leaseKey: string;
  leaseValue: string;
  versionTTLSeconds: number;
  input: Parameters<RedisClient["claimNotification"]>[0];
};

function recipientVersionKey(recipient: NotificationJourneyRecipient) {
  return (
    `${recipient.installationId}\u0000${notificationSubscriptionVersion(recipient)}\u0000` +
    `${recipient.deviceToken}\u0000${recipient.bundleId}\u0000${recipient.environment}`
  );
}

export function journeyDisruptionMatches(
  subscription: Pick<
    NotificationJourneySubscription,
    "routeWindows" | "startsAt" | "endsAt"
  >,
  disruption: Pick<NormalizedDisruption, "routeIds" | "periods">,
  now: Date,
): boolean {
  const nowSeconds = Math.floor(now.getTime() / 1_000);
  const inJourneyWindow =
    now >= subscription.startsAt && now <= subscription.endsAt;
  const touchesJourneyAtTheRightTime = subscription.routeWindows.some(
    (window) =>
      disruption.routeIds.includes(window.routeId) &&
      nowSeconds <= window.endsAt &&
      disruption.periods.some(
        (period) =>
          period.beginsAt <= window.endsAt && period.endsAt >= window.startsAt,
      ),
  );
  const disruptionIsActive = disruption.periods.some(
    (period) => nowSeconds >= period.beginsAt && nowSeconds <= period.endsAt,
  );
  return inJourneyWindow && touchesJourneyAtTheRightTime && disruptionIsActive;
}

// Keyed on the snapshot object, so a new poll's disruptions hash afresh while
// one tick's N recipients share a single hash.
const disruptionVersions = new WeakMap<NormalizedDisruption, string>();

export function disruptionVersion(disruption: NormalizedDisruption): string {
  const cached = disruptionVersions.get(disruption);
  if (cached !== undefined) return cached;
  const version = computeDisruptionVersion(disruption);
  disruptionVersions.set(disruption, version);
  return version;
}

function computeDisruptionVersion(disruption: NormalizedDisruption): string {
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
  subscription: Pick<
    NotificationJourneySubscription,
    "journeyId" | "routeWindows" | "endsAt"
  >,
  disruption: NormalizedDisruption,
  now = new Date(),
): DeviceNotification & { collapseId: string; expirationAt: Date } {
  const deepLink = `via://journey?journeyId=${encodeURIComponent(subscription.journeyId)}&mode=active`;
  const compatibleDeepLink =
    encoder.encode(deepLink).byteLength <= 1_024 ? { deepLink } : {};
  const subscribedRoutes = new Set(
    subscription.routeWindows.map((window) => window.routeId),
  );
  const line =
    disruption.routeIds.find((routeId) => subscribedRoutes.has(routeId)) ??
    "une ligne de votre trajet";
  const collapseId = `via.journey.${stableIdentifierHash(
    `${subscription.journeyId}\u0000${disruption.id}`,
  )}`;
  const nowSeconds = Math.floor(now.getTime() / 1_000);
  // The alert stops being useful once the last overlapping period ends, or
  // when the journey ends, whichever comes first.
  const activePeriodEnds = disruption.periods
    .filter(
      (period) => period.beginsAt <= nowSeconds && period.endsAt >= nowSeconds,
    )
    .map((period) => period.endsAt * 1_000);
  const expirationAt = new Date(
    activePeriodEnds.length === 0
      ? subscription.endsAt.getTime()
      : Math.min(subscription.endsAt.getTime(), Math.max(...activePeriodEnds)),
  );
  const notification = {
    title: truncateUTF8(disruption.title ?? `Perturbation sur ${line}`, 256),
    body: truncateUTF8(
      disruption.message ??
        `Une perturbation touche ${line} pendant votre trajet.`,
      2_500,
    ),
    sound: "default",
    threadId: `via.notification.journey.${stableIdentifierHash(subscription.journeyId)}`,
    categoryId: "via.notification.journey",
    interruptionLevel: disruption.severity === "suspended" ? "timeSensitive" : "active",
    relevanceScore: disruption.severity === "suspended" ? 1 : 0.7,
    expirationAt,
    collapseId,
    data: {
      type: "journey",
      event: "disruption",
      journeyId: subscription.journeyId,
      mode: "active",
      ...compatibleDeepLink,
    },
  } as const;
  return fitDeviceNotification(notification) as DeviceNotification & {
    collapseId: string;
    expirationAt: Date;
  };
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
  private deliveryCircuitOpen = false;

  constructor(
    private readonly options: {
      redis: RedisClient;
      subscriptions: NotificationJourneySubscriptionStore;
      delivery: NotificationDelivery;
      snapshot?: DisruptionSnapshotLoader;
      now?: () => Date;
      shardCount?: number;
      shardCycleMilliseconds?: number;
    },
  ) {}

  async pollOnce(): Promise<void> {
    if (this.isPolling) return;
    this.isPolling = true;
    const now = this.options.now?.() ?? new Date();

    try {
      this.deliveryCircuitOpen =
        (await this.options.redis.get(DELIVERY_CIRCUIT_KEY)) !== null;
      if (this.deliveryCircuitOpen) return;
      if (!(await this.options.subscriptions.hasActive(now))) return;
      const snapshot = await (
        this.options.snapshot ??
        ((date) => getDisruptionsSnapshot(this.options.redis, date))
      )(now);
      if (!snapshot) return;
      const disruptionsByRoute = indexDisruptionsByRoute(snapshot.disruptions);
      const shardCount =
        this.options.shardCount ?? NOTIFICATION_DELIVERY_SHARD_COUNT;
      const shardCycleMilliseconds =
        this.options.shardCycleMilliseconds ?? SHARD_CYCLE_MILLISECONDS;
      const cycle = Math.floor(now.getTime() / shardCycleMilliseconds);
      const shardClaimTTLSeconds = Math.max(
        SHARD_CLAIM_TTL_SECONDS,
        Math.ceil((shardCycleMilliseconds * 2) / 1_000),
      );
      for (let shardIndex = 0; shardIndex < shardCount; shardIndex += 1) {
        const claimed = await this.options.redis.set(
          `notifications:disruption-cycle:${cycle}:shard:${shardIndex}`,
          "1",
          { nx: true, ex: shardClaimTTLSeconds },
        );
        if (claimed === null) continue;
        await this.processShard(
          { index: shardIndex, count: shardCount },
          disruptionsByRoute,
          now,
        );
        if (this.deliveryCircuitOpen) return;
      }
    } catch (error) {
      console.error("[notifications] disruption monitor failed", error);
    } finally {
      await this.cleanupExpired(now);
      this.isPolling = false;
    }
  }

  private async processShard(
    shard: { index: number; count: number },
    disruptionsByRoute: DisruptionsByRoute,
    now: Date,
  ) {
    let afterInstallationId: string | undefined;
    do {
      const recipients = await this.options.subscriptions.listActiveBatch(
        now,
        afterInstallationId,
        SUBSCRIPTION_BATCH_SIZE,
        shard,
      );
      if (recipients.length === 0) break;

      for (
        let start = 0;
        start < recipients.length;
        start += DELIVERY_CONCURRENCY
      ) {
        const currentRecipients =
          await this.options.subscriptions.filterCurrentBatch(
            recipients.slice(start, start + DELIVERY_CONCURRENCY),
          );
        const disruptions = currentRecipients.map((recipient) => ({
          recipient,
          disruptions: this.matchingDisruptions(
            recipient,
            disruptionsByRoute,
            now,
          ),
        }));
        const rounds = Math.max(
          0,
          ...disruptions.map((item) => item.disruptions.length),
        );
        for (let round = 0; round < rounds; round += 1) {
          const claims = disruptions.flatMap((item) => {
            const disruption = item.disruptions[round];
            return disruption
              ? [this.deliveryClaim(item.recipient, disruption, now)]
              : [];
          });
          await this.deliverClaimRound(claims);
          if (this.deliveryCircuitOpen) return;
        }
      }

      afterInstallationId = recipients.at(-1)?.installationId;
      if (recipients.length < SUBSCRIPTION_BATCH_SIZE) break;
    } while (afterInstallationId);
  }

  private async cleanupExpired(now: Date) {
    const deadline = Date.now() + EXPIRATION_CLEANUP_BUDGET_MILLISECONDS;
    try {
      const cycle = Math.floor(now.getTime() / SHARD_CYCLE_MILLISECONDS);
      const claimed = await this.options.redis.set(
        `notifications:subscriptions:cleanup:${cycle}`,
        "1",
        { nx: true, ex: SHARD_CLAIM_TTL_SECONDS },
      );
      if (claimed === null) return;
      let deleted: number;
      do {
        deleted = await this.options.subscriptions.deleteExpiredBatch(
          now,
          EXPIRATION_CLEANUP_BATCH_SIZE,
        );
      } while (
        deleted === EXPIRATION_CLEANUP_BATCH_SIZE &&
        Date.now() < deadline
      );
    } catch (error) {
      console.error(
        "[notifications] expired subscription cleanup failed",
        error,
      );
    }
  }

  private matchingDisruptions(
    subscription: NotificationJourneyRecipient,
    disruptionsByRoute: DisruptionsByRoute,
    now: Date,
  ) {
    const candidates = new Map<string, NormalizedDisruption>();
    for (const routeId of new Set(
      subscription.routeWindows.map((window) => window.routeId),
    )) {
      for (const disruption of disruptionsByRoute.get(routeId) ?? []) {
        candidates.set(disruption.id, disruption);
      }
    }
    return [...candidates.values()].filter((disruption) =>
      journeyDisruptionMatches(subscription, disruption, now),
    );
  }

  private deliveryClaim(
    subscription: NotificationJourneyRecipient,
    disruption: NormalizedDisruption,
    now: Date,
  ): DeliveryClaim {
    const version = disruptionVersion(disruption);
    const dedupKey =
      `notifications:disruption:${subscription.installationId}:` +
      `${subscription.journeyId}:${disruption.id}:${version}`;
    const claimKey = `${dedupKey}:claim`;
    const claimValue = JSON.stringify(crypto.randomUUID());
    const leaseKey = notificationSubscriptionLeaseKey(
      subscription.installationId,
    );
    const leaseValue = JSON.stringify(crypto.randomUUID());
    const versionTTLSeconds = notificationSubscriptionVersionTTLSeconds(
      subscription.endsAt,
    );
    let notification:
      | ReturnType<typeof journeyDisruptionNotification>
      | undefined;
    return {
      subscription,
      disruption,
      notification: () => (notification ??= journeyDisruptionNotification(
        subscription,
        disruption,
        now,
      )),
      dedupKey,
      claimKey,
      claimValue,
      leaseKey,
      leaseValue,
      versionTTLSeconds,
      input: {
        versionKey: notificationSubscriptionVersionKey(
          subscription.installationId,
        ),
        expectedVersion: JSON.stringify(
          notificationSubscriptionVersion(subscription),
        ),
        versionTTLSeconds,
        deliveredKey: dedupKey,
        claimKey,
        claimValue,
        claimTTLSeconds: DELIVERY_CLAIM_TTL_SECONDS,
        leaseKey,
        leaseValue,
        leaseTTLSeconds: DELIVERY_LEASE_TTL_SECONDS,
      },
    };
  }

  private async deliverClaimRound(claims: DeliveryClaim[]) {
    if (claims.length === 0) return;
    let results = await this.claimMany(claims);
    try {
      const staleClaims = claims.filter(
        (_, index) => results[index] === "stale",
      );
      if (staleClaims.length > 0) {
        // Never hold healthy leases while repairing stale cache versions: the
        // repair can legitimately wait behind another delivery lease.
        await Promise.all(
          claims
            .filter((_, index) => results[index] === "claimed")
            .map((claim) => this.releaseDeliveryClaim(claim, true)),
        );
        const current = await this.options.subscriptions.filterCurrentBatch(
          staleClaims.map((claim) => claim.subscription),
        );
        const currentKeys = new Set(current.map(recipientVersionKey));
        await Promise.all(
          staleClaims.map(async (claim) => {
            if (!currentKeys.has(recipientVersionKey(claim.subscription)))
              return;
            await setNotificationSubscriptionVersionWhenIdle(
              this.options.redis,
              claim.subscription.installationId,
              notificationSubscriptionVersion(claim.subscription),
            claim.versionTTLSeconds,
          );
        }),
      );
        results = await this.claimMany(claims);
      }

      const claimed = claims.filter((_, index) => results[index] === "claimed");
      if (claimed.length === 0) return;
      const current = await this.options.subscriptions.filterCurrentBatch(
        claimed.map((claim) => claim.subscription),
      );
      const currentKeys = new Set(current.map(recipientVersionKey));
      const valid: DeliveryClaim[] = [];
      await Promise.all(
        claimed.map(async (claim) => {
          if (currentKeys.has(recipientVersionKey(claim.subscription))) {
            const renewed = await this.options.redis
              .compareAndExpire(
                claim.leaseKey,
                claim.leaseValue,
                DELIVERY_LEASE_TTL_SECONDS,
              )
              .catch(() => false);
            if (renewed) {
              valid.push(claim);
              return;
            }
            await this.releaseDeliveryClaim(claim, true);
            return;
          }
          await this.releaseDeliveryClaim(claim, true);
        }),
      );
      await Promise.all(valid.map((claim) => this.deliverClaim(claim)));
    } catch (error) {
      await Promise.all(
        claims.map((claim) => this.releaseDeliveryClaim(claim, true)),
      );
      throw error;
    }
  }

  private async deliverClaim(claim: DeliveryClaim) {
    let releaseClaim = true;
    try {
      await this.options.delivery.sendToDevice(
        claim.subscription,
        claim.notification(),
      );
      try {
        await this.options.redis.set(claim.dedupKey, "1", {
          ex: DEDUP_TTL_SECONDS,
        });
      } catch (error) {
        releaseClaim = false;
        await this.options.redis
          .compareAndExpire(claim.claimKey, claim.claimValue, DEDUP_TTL_SECONDS)
          .catch(() => false);
        console.error(
          "[notifications] delivered marker persistence failed",
          error,
        );
      }
    } catch (error) {
      // The error class already defaults a non-APNs cause to a retryable
      // global failure; re-deriving that policy here would let the two drift.
      const failure =
        error instanceof NotificationDeliveryError
          ? error
          : new NotificationDeliveryError(error);
      const { retryable, invalidToken } = failure;
      const globalFailure = failure.failureScope === "global";
      if (globalFailure) {
        releaseClaim = false;
        this.deliveryCircuitOpen = true;
        await this.options.redis
          .set(DELIVERY_CIRCUIT_KEY, "1", {
            ex: DELIVERY_CIRCUIT_TTL_SECONDS,
          })
          .catch(() => null);
      } else if (!retryable && !invalidToken) {
        await this.options.redis.set(claim.dedupKey, "1", {
          ex: DEDUP_TTL_SECONDS,
        });
      }
      console.error("[notifications] disruption APNs delivery failed", {
        retryable,
        failureScope: globalFailure ? "global" : "device",
        invalidToken,
        error,
      });
    } finally {
      await this.releaseDeliveryClaim(claim, releaseClaim);
    }
  }

  private async releaseDeliveryClaim(
    claim: DeliveryClaim,
    releaseClaim: boolean,
  ) {
    await this.options.redis
      .compareAndDelete(claim.leaseKey, claim.leaseValue)
      .catch(() => false);
    if (releaseClaim) {
      await this.options.redis
        .compareAndDelete(claim.claimKey, claim.claimValue)
        .catch(() => false);
    }
  }

  private async claimMany(claims: DeliveryClaim[]) {
    const settled = await Promise.allSettled(
      claims.map((claim) => this.options.redis.claimNotification(claim.input)),
    );
    const rejected = settled.filter(
      (result): result is PromiseRejectedResult => result.status === "rejected",
    );
    if (rejected.length > 0) {
      await Promise.all(
        claims.map((claim) => this.releaseDeliveryClaim(claim, true)),
      );
      throw new AggregateError(
        rejected.map((result) => result.reason),
        "Notification claim batch failed.",
      );
    }
    return settled.map((result) =>
      result.status === "fulfilled" ? result.value : "duplicate",
    );
  }
}

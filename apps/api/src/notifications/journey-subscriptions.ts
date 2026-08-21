import { and, asc, eq, gt, inArray, lte, sql } from "drizzle-orm";
import { createHash } from "node:crypto";

import {
  db,
  notificationDevices,
  notificationJourneySubscriptions,
} from "@via/db";
import type {
  ActiveJourneyRegistration,
  ActiveJourneyUnregistration,
} from "@via/contract";
import type { RedisClient } from "../redis";

export type NotificationJourneySubscription =
  typeof notificationJourneySubscriptions.$inferSelect;

export type NotificationJourneyRecipient = Omit<
  NotificationJourneySubscription,
  "deliveryShard" | "routeIds"
> & {
  deviceToken: string;
  bundleId: string;
  environment: "sandbox" | "production";
};

export type NotificationSubscriptionShard = {
  index: number;
  count: number;
};

export class NotificationInstallationOwnershipError extends Error {
  constructor() {
    super("The installation is not owned by this authenticated account.");
    this.name = "NotificationInstallationOwnershipError";
  }
}

export interface NotificationJourneySubscriptionStore {
  register(userId: string, input: ActiveJourneyRegistration): Promise<void>;
  unregister(userId: string, input: ActiveJourneyUnregistration): Promise<void>;
  listActiveBatch(
    now: Date,
    afterInstallationId: string | undefined,
    limit: number,
    shard?: NotificationSubscriptionShard,
  ): Promise<NotificationJourneyRecipient[]>;
  filterCurrentBatch(
    recipients: readonly NotificationJourneyRecipient[],
  ): Promise<NotificationJourneyRecipient[]>;
  deleteExpiredBatch(now: Date, limit: number): Promise<number>;
}

export function activeJourneyRouteWindows(input: ActiveJourneyRegistration) {
  return input.routeWindows.length > 0
    ? input.routeWindows
    : input.routeIds.map((routeId) => ({
        routeId,
        startsAt: input.startsAt,
        endsAt: input.endsAt,
      }));
}

export function notificationSubscriptionVersion(
  value: Pick<
    NotificationJourneySubscription,
    "journeyId" | "routeWindows" | "startsAt" | "endsAt" | "lastSeenAt"
  >,
) {
  const canonical = JSON.stringify({
    journeyId: value.journeyId,
    routeWindows: value.routeWindows
      .map(
        (window) => [window.routeId, window.startsAt, window.endsAt] as const,
      )
      .sort(
        (left, right) =>
          left[0].localeCompare(right[0]) ||
          left[1] - right[1] ||
          left[2] - right[2],
      ),
    startsAt: value.startsAt.getTime(),
    endsAt: value.endsAt.getTime(),
    lastSeenAt: value.lastSeenAt.getTime(),
  });
  return createHash("sha256").update(canonical).digest("base64url");
}

export function notificationSubscriptionVersionKey(installationId: string) {
  return `notifications:subscription:${installationId}:version`;
}

export function notificationSubscriptionLeaseKey(installationId: string) {
  return `notifications:subscription:${installationId}:delivery-lease`;
}

const VERSION_TTL_FLOOR_SECONDS = 60 * 60;
const TOMBSTONE_TTL_SECONDS = 25 * 60 * 60;
// The monitor holds a 60-second delivery lease around the complete APNs
// exchange. Mutations wait slightly longer so they never race its retry.
const VERSION_IDLE_WAIT_MILLISECONDS = 65_000;

/**
 * A cached version outlives its journey by an hour so a late delivery still
 * reads the version that was current when the journey ended.
 */
export function notificationSubscriptionVersionTTLSeconds(
  endsAt: Date,
  now = new Date(),
) {
  return Math.max(
    VERSION_TTL_FLOOR_SECONDS,
    Math.ceil((endsAt.getTime() - now.getTime()) / 1_000) +
      VERSION_TTL_FLOOR_SECONDS,
  );
}

/**
 * A removed subscription must never match a cached version, so each tombstone
 * is unique and outlives the 24-hour journey cap.
 */
export function notificationSubscriptionTombstone() {
  return {
    value: `removed\u0000${crypto.randomUUID()}`,
    ttlSeconds: TOMBSTONE_TTL_SECONDS,
  };
}

export async function setNotificationSubscriptionVersionWhenIdle(
  redis: RedisClient,
  installationId: string,
  value: string,
  ttlSeconds: number,
) {
  const deadline = Date.now() + VERSION_IDLE_WAIT_MILLISECONDS;
  let backoffMilliseconds = 100;
  for (;;) {
    const updated = await redis.setSubscriptionVersionWhenIdle({
      versionKey: notificationSubscriptionVersionKey(installationId),
      leaseKey: notificationSubscriptionLeaseKey(installationId),
      value: JSON.stringify(value),
      ttlSeconds,
    });
    if (updated) return;
    if (Date.now() >= deadline) break;
    await new Promise((resolve) => setTimeout(resolve, backoffMilliseconds));
    backoffMilliseconds = Math.min(backoffMilliseconds * 2, 1_000);
  }
  throw new Error("Timed out updating the notification subscription version.");
}

export function createDatabaseNotificationJourneySubscriptionStore(
  redis: RedisClient,
): NotificationJourneySubscriptionStore {
  return {
    async register(userId, input) {
      const routeWindows = activeJourneyRouteWindows(input);
      // One encoding feeds the row, the conflict update and the cached version;
      // a second copy could drift and silently invalidate every delivery.
      const encodedWindows = routeWindows.map((window) => ({
        routeId: window.routeId,
        startsAt: Math.floor(Date.parse(window.startsAt) / 1_000),
        endsAt: Math.floor(Date.parse(window.endsAt) / 1_000),
      }));
      // Kept for one rolling-deploy window so an ae27 replica can still
      // process subscriptions written by the new route-window model.
      const legacyRouteIds = [
        ...new Set(routeWindows.map((window) => window.routeId)),
      ];
      const startsAt = new Date(input.startsAt);
      const endsAt = new Date(input.endsAt);
      const now = await db.transaction(async (transaction) => {
        await transaction.execute(
          sql`select pg_advisory_xact_lock(hashtext(${input.installationId}))`,
        );
        const device = await transaction
          .select({ userId: notificationDevices.userId })
          .from(notificationDevices)
          .where(eq(notificationDevices.installationId, input.installationId))
          .limit(1)
          .for("update");
        if (device[0]?.userId !== userId) {
          throw new NotificationInstallationOwnershipError();
        }
        const now = new Date();
        const row = {
          userId,
          journeyId: input.journeyId,
          routeIds: legacyRouteIds,
          routeWindows: encodedWindows,
          startsAt,
          endsAt,
          lastSeenAt: now,
        };
        await transaction
          .insert(notificationJourneySubscriptions)
          .values({ installationId: input.installationId, ...row })
          .onConflictDoUpdate({
            target: notificationJourneySubscriptions.installationId,
            set: row,
          });
        return now;
      });
      await setNotificationSubscriptionVersionWhenIdle(
        redis,
        input.installationId,
        notificationSubscriptionVersion({
          journeyId: input.journeyId,
          routeWindows: encodedWindows,
          startsAt,
          endsAt,
          lastSeenAt: now,
        }),
        notificationSubscriptionVersionTTLSeconds(endsAt),
      ).catch((error) => {
        console.error("[notifications] subscription cache sync failed", error);
      });
    },

    async unregister(userId, input) {
      const removed = await db.transaction(async (transaction) => {
        await transaction.execute(
          sql`select pg_advisory_xact_lock(hashtext(${input.installationId}))`,
        );
        const deleted = await transaction
          .delete(notificationJourneySubscriptions)
          .where(
            and(
              eq(notificationJourneySubscriptions.userId, userId),
              eq(
                notificationJourneySubscriptions.installationId,
                input.installationId,
              ),
              eq(notificationJourneySubscriptions.journeyId, input.journeyId),
            ),
          )
          .returning({
            installationId: notificationJourneySubscriptions.installationId,
          });
        return deleted.length > 0;
      });
      if (removed) {
        const tombstone = notificationSubscriptionTombstone();
        await setNotificationSubscriptionVersionWhenIdle(
          redis,
          input.installationId,
          tombstone.value,
          tombstone.ttlSeconds,
        ).catch((error) => {
          console.error(
            "[notifications] subscription tombstone sync failed",
            error,
          );
        });
      }
    },

    async listActiveBatch(now, afterInstallationId, limit, shard) {
      const rows = await db
        .select({
          installationId: notificationJourneySubscriptions.installationId,
          userId: notificationJourneySubscriptions.userId,
          journeyId: notificationJourneySubscriptions.journeyId,
          routeWindows: notificationJourneySubscriptions.routeWindows,
          startsAt: notificationJourneySubscriptions.startsAt,
          endsAt: notificationJourneySubscriptions.endsAt,
          createdAt: notificationJourneySubscriptions.createdAt,
          lastSeenAt: notificationJourneySubscriptions.lastSeenAt,
          deviceToken: notificationDevices.deviceToken,
          bundleId: notificationDevices.bundleId,
          environment: notificationDevices.environment,
          legacyRouteIds: sql<
            string[]
          >`notification_journey_subscriptions.route_ids`,
        })
        .from(notificationJourneySubscriptions)
        .innerJoin(
          notificationDevices,
          and(
            eq(
              notificationDevices.installationId,
              notificationJourneySubscriptions.installationId,
            ),
            eq(
              notificationDevices.userId,
              notificationJourneySubscriptions.userId,
            ),
          ),
        )
        .where(
          and(
            gt(notificationJourneySubscriptions.endsAt, now),
            lte(notificationJourneySubscriptions.startsAt, now),
            shard
              ? eq(notificationJourneySubscriptions.deliveryShard, shard.index)
              : undefined,
            afterInstallationId
              ? gt(
                  notificationJourneySubscriptions.installationId,
                  afterInstallationId,
                )
              : undefined,
          ),
        )
        .orderBy(asc(notificationJourneySubscriptions.installationId))
        .limit(limit);
      return rows.map(({ legacyRouteIds, ...row }) => ({
        ...row,
        routeWindows:
          row.routeWindows.length > 0
            ? row.routeWindows
            : legacyRouteIds.map((routeId) => ({
                routeId,
                startsAt: Math.floor(row.startsAt.getTime() / 1_000),
                endsAt: Math.floor(row.endsAt.getTime() / 1_000),
              })),
      }));
    },

    async filterCurrentBatch(recipients) {
      if (recipients.length === 0) return [];
      const current = await db
        .select({
          installationId: notificationJourneySubscriptions.installationId,
          journeyId: notificationJourneySubscriptions.journeyId,
          routeWindows: notificationJourneySubscriptions.routeWindows,
          startsAt: notificationJourneySubscriptions.startsAt,
          endsAt: notificationJourneySubscriptions.endsAt,
          lastSeenAt: notificationJourneySubscriptions.lastSeenAt,
          deviceToken: notificationDevices.deviceToken,
          bundleId: notificationDevices.bundleId,
          environment: notificationDevices.environment,
        })
        .from(notificationJourneySubscriptions)
        .innerJoin(
          notificationDevices,
          and(
            eq(
              notificationDevices.installationId,
              notificationJourneySubscriptions.installationId,
            ),
            eq(
              notificationDevices.userId,
              notificationJourneySubscriptions.userId,
            ),
          ),
        )
        .where(
          inArray(
            notificationJourneySubscriptions.installationId,
            recipients.map((recipient) => recipient.installationId),
          ),
        );
      const currentVersions = new Map(
        current.map((subscription) => [
          subscription.installationId,
          {
            version: notificationSubscriptionVersion(subscription),
            deviceToken: subscription.deviceToken,
            bundleId: subscription.bundleId,
            environment: subscription.environment,
          },
        ]),
      );
      return recipients.filter((recipient) => {
        const current = currentVersions.get(recipient.installationId);
        return (
          current?.version === notificationSubscriptionVersion(recipient) &&
          current.deviceToken === recipient.deviceToken &&
          current.bundleId === recipient.bundleId &&
          current.environment === recipient.environment
        );
      });
    },

    async deleteExpiredBatch(now, limit) {
      const expired = db
        .select({
          installationId: notificationJourneySubscriptions.installationId,
        })
        .from(notificationJourneySubscriptions)
        .where(lte(notificationJourneySubscriptions.endsAt, now))
        .orderBy(asc(notificationJourneySubscriptions.endsAt))
        .limit(limit);
      const deleted = await db
        .delete(notificationJourneySubscriptions)
        .where(
          inArray(notificationJourneySubscriptions.installationId, expired),
        )
        .returning({
          installationId: notificationJourneySubscriptions.installationId,
        });
      return deleted.length;
    },
  };
}

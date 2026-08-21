import { and, desc, eq, inArray, lte, ne, or, sql } from "drizzle-orm";
import { db, notificationDevices } from "@via/db";
import type {
  APNsEnvironment,
  NotificationDeviceRegistration,
} from "@via/contract";
import type { RedisClient } from "../redis";
import {
  notificationSubscriptionTombstone,
  setNotificationSubscriptionVersionWhenIdle,
} from "./journey-subscriptions";

export type NotificationDevice = typeof notificationDevices.$inferSelect;

type Transaction = Parameters<Parameters<typeof db.transaction>[0]>[0];

const MAXIMUM_DEVICES_PER_USER = 8;

export async function tombstoneNotificationInstallations(
  redis: RedisClient,
  installationIds: readonly string[],
) {
  await Promise.all(
    [...new Set(installationIds)].map((installationId) => {
      const tombstone = notificationSubscriptionTombstone();
      return setNotificationSubscriptionVersionWhenIdle(
        redis,
        installationId,
        tombstone.value,
        tombstone.ttlSeconds,
      );
    }),
  );
}

/**
 * Advisory locks are always taken in code-point order, so two transactions
 * touching the same installations can never take them in opposite orders.
 */
export async function lockInstallations(
  transaction: Transaction,
  installationIds: readonly string[],
) {
  for (const installationId of [...new Set(installationIds)].sort()) {
    await transaction.execute(
      sql`select pg_advisory_xact_lock(hashtext(${installationId}))`,
    );
  }
}

export interface NotificationTokenStore {
  registerDevice(
    userId: string,
    input: NotificationDeviceRegistration,
  ): Promise<void>;
  unregisterDevice(userId: string, installationId: string): Promise<void>;
  removeDeviceToken(
    token: string,
    bundleId: string,
    environment: APNsEnvironment,
    invalidatedAt?: Date,
  ): Promise<void>;
}

/**
 * Database adapter for APNs token ownership. The provider never receives a
 * user id from the client; this adapter is always called with the authenticated
 * context supplied by the router or by a trusted delivery job.
 */
export function createDatabaseNotificationTokenStore(
  redis: RedisClient,
): NotificationTokenStore {
  async function tombstoneInstallations(installationIds: readonly string[]) {
    await tombstoneNotificationInstallations(redis, installationIds).catch(
      (error) => {
        console.error("[notifications] device tombstone sync failed", error);
      },
    );
  }

  return {
    async registerDevice(userId, input) {
      const invalidated = await db.transaction(async (transaction) => {
        await transaction.execute(
          sql`select pg_advisory_xact_lock(hashtext(${userId}))`,
        );
        await transaction.execute(
          sql`select pg_advisory_xact_lock(hashtext(${`${input.bundleId}\u0000${input.environment}\u0000${input.deviceToken}`}))`,
        );
        const now = new Date();
        const displacedCondition = or(
          and(
            eq(notificationDevices.bundleId, input.bundleId),
            eq(notificationDevices.environment, input.environment),
            eq(notificationDevices.deviceToken, input.deviceToken),
            ne(notificationDevices.installationId, input.installationId),
          ),
          and(
            eq(notificationDevices.installationId, input.installationId),
            ne(notificationDevices.userId, userId),
          ),
        );
        const displaced = await transaction
          .select({ installationId: notificationDevices.installationId })
          .from(notificationDevices)
          .where(displacedCondition);
        await lockInstallations(transaction, [
          input.installationId,
          ...displaced.map((device) => device.installationId),
        ]);
        const lockedDisplaced = await transaction
          .select({ installationId: notificationDevices.installationId })
          .from(notificationDevices)
          .where(displacedCondition)
          .for("update");
        // APNs can issue the same opaque token to a new installation after a
        // restore. Keep one owner and let the newest authenticated install win.
        await transaction
          .delete(notificationDevices)
          .where(
            and(
              eq(notificationDevices.bundleId, input.bundleId),
              eq(notificationDevices.environment, input.environment),
              eq(notificationDevices.deviceToken, input.deviceToken),
              ne(notificationDevices.installationId, input.installationId),
            ),
          );

        // Re-associating an installation with another account must discard
        // every child registration owned by the previous account. Same-user
        // token refreshes keep the active journey subscription intact.
        await transaction
          .delete(notificationDevices)
          .where(
            and(
              eq(notificationDevices.installationId, input.installationId),
              ne(notificationDevices.userId, userId),
            ),
          );

        await transaction
          .insert(notificationDevices)
          .values({
            installationId: input.installationId,
            userId,
            deviceToken: input.deviceToken,
            bundleId: input.bundleId,
            environment: input.environment,
            appVersion: input.appVersion ?? null,
            osVersion: input.osVersion ?? null,
            lastSeenAt: now,
          })
          .onConflictDoUpdate({
            target: notificationDevices.installationId,
            set: {
              userId,
              deviceToken: input.deviceToken,
              bundleId: input.bundleId,
              environment: input.environment,
              appVersion: input.appVersion ?? null,
              osVersion: input.osVersion ?? null,
              lastSeenAt: now,
            },
          });

        const surplus = await transaction
          .select({ installationId: notificationDevices.installationId })
          .from(notificationDevices)
          .where(
            and(
              eq(notificationDevices.userId, userId),
              ne(notificationDevices.installationId, input.installationId),
            ),
          )
          .orderBy(desc(notificationDevices.lastSeenAt))
          .offset(MAXIMUM_DEVICES_PER_USER - 1);
        if (surplus.length > 0) {
          await lockInstallations(
            transaction,
            surplus.map((device) => device.installationId),
          );
          await transaction.delete(notificationDevices).where(
            and(
              eq(notificationDevices.userId, userId),
              inArray(
                notificationDevices.installationId,
                surplus.map((device) => device.installationId),
              ),
            ),
          );
        }
        return [
          input.installationId,
          ...lockedDisplaced.map((device) => device.installationId),
          ...surplus.map((device) => device.installationId),
        ];
      });
      await tombstoneInstallations(invalidated);
    },

    async unregisterDevice(userId, installationId) {
      const removed = await db.transaction(async (transaction) => {
        await transaction.execute(
          sql`select pg_advisory_xact_lock(hashtext(${installationId}))`,
        );
        const deleted = await transaction
          .delete(notificationDevices)
          .where(
            and(
              eq(notificationDevices.userId, userId),
              eq(notificationDevices.installationId, installationId),
            ),
          )
          .returning({ installationId: notificationDevices.installationId });
        return deleted.length > 0;
      });
      if (removed) await tombstoneInstallations([installationId]);
    },

    async removeDeviceToken(token, bundleId, environment, invalidatedAt) {
      const removedInstallationIds = await db.transaction(
        async (transaction) => {
          const condition = and(
            eq(notificationDevices.deviceToken, token),
            eq(notificationDevices.bundleId, bundleId),
            eq(notificationDevices.environment, environment),
            invalidatedAt
              ? lte(notificationDevices.lastSeenAt, invalidatedAt)
              : undefined,
          );
          const current = await transaction
            .select({ installationId: notificationDevices.installationId })
            .from(notificationDevices)
            .where(condition);
          await lockInstallations(
            transaction,
            current.map((device) => device.installationId),
          );
          const lockedCurrent = await transaction
            .select({ installationId: notificationDevices.installationId })
            .from(notificationDevices)
            .where(condition)
            .for("update");
          if (lockedCurrent.length > 0) {
            await transaction.delete(notificationDevices).where(condition);
          }
          return lockedCurrent.map((device) => device.installationId);
        },
      );
      await tombstoneInstallations(removedInstallationIds);
    },
  };
}

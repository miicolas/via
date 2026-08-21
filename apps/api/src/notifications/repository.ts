import { and, eq, ne } from "drizzle-orm";
import {
  db,
  notificationDevices,
  notificationLiveActivities,
  notificationLiveActivityStartTokens,
} from "@via/db";
import type {
  APNsEnvironment,
  LiveActivityPushToStartRegistration,
  LiveActivityRegistration,
  NotificationDeviceRegistration,
} from "@via/contract";

export type NotificationDevice = typeof notificationDevices.$inferSelect;

export interface NotificationTokenStore {
  registerDevice(
    userId: string,
    input: NotificationDeviceRegistration,
  ): Promise<void>;
  unregisterDevice(userId: string, installationId: string): Promise<void>;
  registerActivity(
    userId: string,
    input: LiveActivityRegistration,
  ): Promise<void>;
  unregisterActivity(userId: string, activityId: string): Promise<void>;
  registerPushToStartToken(
    userId: string,
    input: LiveActivityPushToStartRegistration,
  ): Promise<void>;
  removeDeviceToken(
    token: string,
    bundleId: string,
    environment: APNsEnvironment,
  ): Promise<void>;
}

/**
 * Database adapter for APNs token ownership. The provider never receives a
 * user id from the client; this adapter is always called with the authenticated
 * context supplied by the router or by a trusted delivery job.
 */
export function createDatabaseNotificationTokenStore(): NotificationTokenStore {
  return {
    async registerDevice(userId, input) {
      const now = new Date();
      await db.transaction(async (transaction) => {
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
      });
    },

    async unregisterDevice(userId, installationId) {
      await db
        .delete(notificationDevices)
        .where(
          and(
            eq(notificationDevices.userId, userId),
            eq(notificationDevices.installationId, installationId),
          ),
        );
    },

    async registerActivity(userId, input) {
      const now = new Date();
      await db.transaction(async (transaction) => {
        await transaction
          .delete(notificationLiveActivities)
          .where(
            and(
              eq(notificationLiveActivities.bundleId, input.bundleId),
              eq(notificationLiveActivities.environment, input.environment),
              eq(notificationLiveActivities.activityToken, input.activityToken),
              ne(notificationLiveActivities.activityId, input.activityId),
            ),
          );

        await transaction
          .insert(notificationLiveActivities)
          .values({
            activityId: input.activityId,
            userId,
            installationId: input.installationId,
            journeyId: input.journeyId,
            activityToken: input.activityToken,
            bundleId: input.bundleId,
            environment: input.environment,
            lastSeenAt: now,
          })
          .onConflictDoUpdate({
            target: notificationLiveActivities.activityId,
            set: {
              userId,
              installationId: input.installationId,
              journeyId: input.journeyId,
              activityToken: input.activityToken,
              bundleId: input.bundleId,
              environment: input.environment,
              lastSeenAt: now,
            },
          });
      });
    },

    async unregisterActivity(userId, activityId) {
      await db
        .delete(notificationLiveActivities)
        .where(
          and(
            eq(notificationLiveActivities.userId, userId),
            eq(notificationLiveActivities.activityId, activityId),
          ),
        );
    },

    async registerPushToStartToken(userId, input) {
      const now = new Date();
      await db.transaction(async (transaction) => {
        await transaction
          .delete(notificationLiveActivityStartTokens)
          .where(
            and(
              eq(notificationLiveActivityStartTokens.bundleId, input.bundleId),
              eq(
                notificationLiveActivityStartTokens.environment,
                input.environment,
              ),
              eq(
                notificationLiveActivityStartTokens.pushToStartToken,
                input.pushToStartToken,
              ),
              ne(
                notificationLiveActivityStartTokens.installationId,
                input.installationId,
              ),
            ),
          );

        await transaction
          .insert(notificationLiveActivityStartTokens)
          .values({
            installationId: input.installationId,
            userId,
            pushToStartToken: input.pushToStartToken,
            bundleId: input.bundleId,
            environment: input.environment,
            lastSeenAt: now,
          })
          .onConflictDoUpdate({
            target: notificationLiveActivityStartTokens.installationId,
            set: {
              userId,
              pushToStartToken: input.pushToStartToken,
              bundleId: input.bundleId,
              environment: input.environment,
              lastSeenAt: now,
            },
          });
      });
    },

    async removeDeviceToken(token, bundleId, environment) {
      await db
        .delete(notificationDevices)
        .where(
          and(
            eq(notificationDevices.deviceToken, token),
            eq(notificationDevices.bundleId, bundleId),
            eq(notificationDevices.environment, environment),
          ),
        );
    },
  };
}

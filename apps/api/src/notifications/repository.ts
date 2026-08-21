import { and, eq, inArray, ne } from "drizzle-orm";
import {
  db,
  notificationDevices,
  notificationLiveActivities,
  notificationLiveActivityStartTokens,
  notificationJourneySubscriptions,
} from "@via/db";
import type {
  APNsEnvironment,
  LiveActivityPushToStartRegistration,
  LiveActivityRegistration,
  NotificationDeviceRegistration,
} from "@via/contract";

export type NotificationDevice = typeof notificationDevices.$inferSelect;
export type NotificationLiveActivity =
  typeof notificationLiveActivities.$inferSelect;
export type NotificationStartToken =
  typeof notificationLiveActivityStartTokens.$inferSelect;

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
  listDevices(userId: string): Promise<NotificationDevice[]>;
  getActivity(activityId: string): Promise<NotificationLiveActivity | null>;
  listActivities(journeyId: string): Promise<NotificationLiveActivity[]>;
  getPushToStartTokens(userId: string): Promise<NotificationStartToken[]>;
  removeDeviceToken(
    token: string,
    bundleId: string,
    environment: APNsEnvironment,
  ): Promise<void>;
  removeActivityToken(
    token: string,
    bundleId: string,
    environment: APNsEnvironment,
  ): Promise<void>;
  removePushToStartToken(
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

        await transaction
          .delete(notificationJourneySubscriptions)
          .where(eq(notificationJourneySubscriptions.installationId, input.installationId));

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
      await db.transaction(async (transaction) => {
        await transaction
          .delete(notificationDevices)
          .where(
            and(
              eq(notificationDevices.userId, userId),
              eq(notificationDevices.installationId, installationId),
            ),
          );
        await transaction
          .delete(notificationLiveActivities)
          .where(
            and(
              eq(notificationLiveActivities.userId, userId),
              eq(notificationLiveActivities.installationId, installationId),
            ),
          );
        await transaction
          .delete(notificationLiveActivityStartTokens)
          .where(
            and(
              eq(notificationLiveActivityStartTokens.userId, userId),
              eq(
                notificationLiveActivityStartTokens.installationId,
                installationId,
              ),
            ),
          );
        await transaction
          .delete(notificationJourneySubscriptions)
          .where(
            and(
              eq(notificationJourneySubscriptions.userId, userId),
              eq(notificationJourneySubscriptions.installationId, installationId),
            ),
          );
      });
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

    async listDevices(userId) {
      return db
        .select()
        .from(notificationDevices)
        .where(eq(notificationDevices.userId, userId));
    },

    async getActivity(activityId) {
      const rows = await db
        .select()
        .from(notificationLiveActivities)
        .where(eq(notificationLiveActivities.activityId, activityId))
        .limit(1);
      return rows[0] ?? null;
    },

    async listActivities(journeyId) {
      return db
        .select()
        .from(notificationLiveActivities)
        .where(eq(notificationLiveActivities.journeyId, journeyId));
    },

    async getPushToStartTokens(userId) {
      return db
        .select()
        .from(notificationLiveActivityStartTokens)
        .where(eq(notificationLiveActivityStartTokens.userId, userId));
    },

    async removeDeviceToken(token, bundleId, environment) {
      await db.transaction(async (transaction) => {
        const devices = await transaction
          .select({ installationId: notificationDevices.installationId })
          .from(notificationDevices)
          .where(
            and(
              eq(notificationDevices.deviceToken, token),
              eq(notificationDevices.bundleId, bundleId),
              eq(notificationDevices.environment, environment),
            ),
          );
        await transaction
          .delete(notificationDevices)
          .where(
            and(
              eq(notificationDevices.deviceToken, token),
              eq(notificationDevices.bundleId, bundleId),
              eq(notificationDevices.environment, environment),
            ),
          );
        const installationIDs = devices.map((device) => device.installationId);
        if (installationIDs.length > 0) {
          await transaction
            .delete(notificationJourneySubscriptions)
            .where(inArray(notificationJourneySubscriptions.installationId, installationIDs));
        }
      });
    },

    async removeActivityToken(token, bundleId, environment) {
      await db
        .delete(notificationLiveActivities)
        .where(
          and(
            eq(notificationLiveActivities.activityToken, token),
            eq(notificationLiveActivities.bundleId, bundleId),
            eq(notificationLiveActivities.environment, environment),
          ),
        );
    },

    async removePushToStartToken(token, bundleId, environment) {
      await db
        .delete(notificationLiveActivityStartTokens)
        .where(
          and(
            eq(notificationLiveActivityStartTokens.pushToStartToken, token),
            eq(notificationLiveActivityStartTokens.bundleId, bundleId),
            eq(notificationLiveActivityStartTokens.environment, environment),
          ),
        );
    },
  };
}

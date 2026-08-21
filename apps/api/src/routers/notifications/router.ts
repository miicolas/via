import { ORPCError } from "@orpc/server";

import { env } from "../../env";
import { implementer } from "../../orpc/implementer";
import { notificationJourneySubscriptions } from "../../notifications";
import { NotificationInstallationOwnershipError } from "../../notifications/journey-subscriptions";
import { createDatabaseNotificationTokenStore } from "../../notifications/repository";

const tokenStore = createDatabaseNotificationTokenStore();

function authenticatedUser(
  userId: string | undefined,
  isAnonymous?: boolean,
): string {
  if (!userId || isAnonymous) throw new ORPCError("UNAUTHORIZED");
  return userId;
}

function validateBundleID(bundleId: string) {
  if (bundleId !== env.APNS_BUNDLE_ID) throw new ORPCError("BAD_REQUEST");
}

const registerDevice = implementer.notifications.registerDevice.handler(
  async ({ input, context }) => {
    const userId = authenticatedUser(context.userId, context.isAnonymous);
    validateBundleID(input.bundleId);
    await tokenStore.registerDevice(userId, input);
    return { registered: true as const };
  },
);

const unregisterDevice = implementer.notifications.unregisterDevice.handler(
  async ({ input, context }) => {
    const userId = authenticatedUser(context.userId, context.isAnonymous);
    await tokenStore.unregisterDevice(userId, input.installationId);
    return { removed: true as const };
  },
);

const registerActivity = implementer.notifications.registerActivity.handler(
  async ({ input, context }) => {
    const userId = authenticatedUser(context.userId, context.isAnonymous);
    validateBundleID(input.bundleId);
    await tokenStore.registerActivity(userId, input);
    return { registered: true as const };
  },
);

const unregisterActivity = implementer.notifications.unregisterActivity.handler(
  async ({ input, context }) => {
    const userId = authenticatedUser(context.userId, context.isAnonymous);
    await tokenStore.unregisterActivity(userId, input.activityId);
    return { removed: true as const };
  },
);

const registerPushToStart =
  implementer.notifications.registerPushToStart.handler(
    async ({ input, context }) => {
      const userId = authenticatedUser(context.userId, context.isAnonymous);
      validateBundleID(input.bundleId);
      await tokenStore.registerPushToStartToken(userId, input);
      return { registered: true as const };
    },
  );

const registerActiveJourney =
  implementer.notifications.registerActiveJourney.handler(
    async ({ input, context }) => {
      const userId = authenticatedUser(context.userId, context.isAnonymous);
      try {
        await notificationJourneySubscriptions.register(userId, input);
      } catch (error) {
        if (error instanceof NotificationInstallationOwnershipError) {
          throw new ORPCError("FORBIDDEN");
        }
        throw error;
      }
      return { registered: true as const };
    },
  );

const unregisterActiveJourney =
  implementer.notifications.unregisterActiveJourney.handler(
    async ({ input, context }) => {
      const userId = authenticatedUser(context.userId, context.isAnonymous);
      await notificationJourneySubscriptions.unregister(userId, input);
      return { removed: true as const };
    },
  );

export const notificationsRouter = {
  registerDevice,
  unregisterDevice,
  registerActivity,
  unregisterActivity,
  registerPushToStart,
  registerActiveJourney,
  unregisterActiveJourney,
};

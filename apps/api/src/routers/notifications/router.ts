import { ORPCError } from "@orpc/server";

import { env } from "../../env";
import { implementer } from "../../orpc/implementer";
import {
  notificationJourneySubscriptions,
  notificationTokenStore,
} from "../../notifications";
import { NotificationInstallationOwnershipError } from "../../notifications/journey-subscriptions";

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

const MAXIMUM_JOURNEY_WINDOW_MILLISECONDS = 24 * 60 * 60 * 1_000;

export function validateActiveJourneyWindow(
  input: { startsAt: string; endsAt: string },
  now = new Date(),
) {
  const startsAt = Date.parse(input.startsAt);
  const endsAt = Date.parse(input.endsAt);
  const currentTime = now.getTime();
  if (
    !Number.isFinite(startsAt) ||
    !Number.isFinite(endsAt) ||
    startsAt > endsAt ||
    endsAt <= currentTime ||
    startsAt < currentTime - MAXIMUM_JOURNEY_WINDOW_MILLISECONDS ||
    endsAt > currentTime + MAXIMUM_JOURNEY_WINDOW_MILLISECONDS ||
    endsAt - startsAt > MAXIMUM_JOURNEY_WINDOW_MILLISECONDS
  ) {
    throw new ORPCError("BAD_REQUEST");
  }
}

const registerDevice = implementer.notifications.registerDevice.handler(
  async ({ input, context }) => {
    const userId = authenticatedUser(context.userId, context.isAnonymous);
    validateBundleID(input.bundleId);
    await notificationTokenStore.registerDevice(userId, input);
    return { registered: true as const };
  },
);

const unregisterDevice = implementer.notifications.unregisterDevice.handler(
  async ({ input, context }) => {
    const userId = authenticatedUser(context.userId, context.isAnonymous);
    await notificationTokenStore.unregisterDevice(userId, input.installationId);
    return { removed: true as const };
  },
);

const registerActivity = implementer.notifications.registerActivity.handler(
  async ({ context }) => {
    authenticatedUser(context.userId, context.isAnonymous);
    return { registered: true as const };
  },
);

const unregisterActivity = implementer.notifications.unregisterActivity.handler(
  async ({ context }) => {
    authenticatedUser(context.userId, context.isAnonymous);
    return { removed: true as const };
  },
);

const registerPushToStart =
  implementer.notifications.registerPushToStart.handler(async ({ context }) => {
    authenticatedUser(context.userId, context.isAnonymous);
    return { registered: true as const };
  });

const registerActiveJourney =
  implementer.notifications.registerActiveJourney.handler(
    async ({ input, context }) => {
      const userId = authenticatedUser(context.userId, context.isAnonymous);
      validateActiveJourneyWindow(input);
      try {
        // The store owns the legacy routeIds fallback via
        // activeJourneyRouteWindows; expanding it here too would let the two
        // copies of the migration rule drift apart.
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

import { env } from "../env";

import { createAPNsProvider } from "./apns";
import { createNotificationDelivery } from "./delivery";
import { createDatabaseNotificationTokenStore } from "./repository";
import { createDatabaseNotificationJourneySubscriptionStore } from "./journey-subscriptions";

/**
 * Shared delivery seam for trusted jobs and domain handlers. Registration is
 * still useful without APNs credentials; delivery fails explicitly until the
 * deployment supplies the provider key.
 */
export const notificationDelivery = createNotificationDelivery({
  apns:
    env.APNS_KEY_ID && env.APNS_PRIVATE_KEY
      ? createAPNsProvider({
          teamId: env.APNS_TEAM_ID,
          keyId: env.APNS_KEY_ID,
          privateKey: env.APNS_PRIVATE_KEY,
        })
      : null,
  tokens: createDatabaseNotificationTokenStore(),
});

export const notificationJourneySubscriptions =
  createDatabaseNotificationJourneySubscriptionStore();

export * from "./apns";
export * from "./delivery";
export * from "./repository";
export * from "./journey-subscriptions";

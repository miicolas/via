import { env } from "../env";
import { redis } from "../redis";
import { jobDb } from "@via/db";

import { createAPNsProvider } from "./apns";
import { createNotificationDelivery } from "./delivery";
import { createDatabaseNotificationTokenStore } from "./repository";
import { createDatabaseNotificationJourneySubscriptionStore } from "./journey-subscriptions";

/**
 * Shared delivery seam for trusted jobs and domain handlers. Registration is
 * still useful without APNs credentials; delivery fails explicitly until the
 * deployment supplies the provider key.
 */
export const notificationTokenStore = createDatabaseNotificationTokenStore(redis);
const notificationJobTokenStore = createDatabaseNotificationTokenStore(redis, jobDb);

export const notificationDelivery = createNotificationDelivery({
  apns:
    env.APNS_KEY_ID && env.APNS_PRIVATE_KEY
      ? createAPNsProvider({
          teamId: env.APNS_TEAM_ID,
          keyId: env.APNS_KEY_ID,
          privateKey: env.APNS_PRIVATE_KEY,
        })
      : null,
  tokens: notificationJobTokenStore,
});

export const notificationJourneySubscriptions =
  createDatabaseNotificationJourneySubscriptionStore(redis);

export * from "./apns";
export * from "./delivery";
export * from "./repository";
export * from "./journey-subscriptions";
export * from "./inbox-store";
export {
  fitDeviceNotification,
  payloadByteLength,
  stableIdentifierHash,
  truncateUTF8,
} from "./payload";
export type { DeviceNotification } from "./payload";
export * from "./policy";
export * from "./preferences";
export * from "./recurrence";
export * from "./render";

import type { APNsEnvironment } from "@via/contract";

import {
  APNsError,
  type APNsProvider,
  deviceNotificationPayload,
  type DeviceNotification,
} from "./apns";
import type { NotificationTokenStore } from "./repository";

export class APNsNotConfiguredError extends Error {
  constructor() {
    super("APNs provider credentials are not configured.");
    this.name = "APNsNotConfiguredError";
  }
}

export class NotificationDeliveryError extends Error {
  readonly retryable: boolean;
  readonly failureScope: "device" | "global";
  readonly invalidToken: boolean;

  constructor(readonly deliveryCause: unknown) {
    const apnsError =
      deliveryCause instanceof APNsError ? deliveryCause : undefined;
    super(apnsError ? `APNs: ${apnsError.reason}` : "APNs transport failed");
    this.name = "NotificationDeliveryError";
    this.retryable = apnsError?.isRetryable ?? true;
    this.failureScope = apnsError?.failureScope ?? "global";
    this.invalidToken = apnsError?.isInvalidToken ?? false;
  }
}

export type NotificationDeviceTarget = {
  deviceToken: string;
  bundleId: string;
  environment: APNsEnvironment;
};

export interface NotificationDelivery {
  sendToDevice(
    target: NotificationDeviceTarget,
    notification: DeviceNotification,
  ): Promise<void>;
  /** Fan-out is keyed by account, so one occurrence produces one inbox row. */
  sendToUser?(userId: string, notification: DeviceNotification): Promise<void>;
}

export function createNotificationDelivery(options: {
  apns: APNsProvider | null;
  tokens: NotificationTokenStore;
}): NotificationDelivery {
  function provider(): APNsProvider {
    if (!options.apns) throw new APNsNotConfiguredError();
    return options.apns;
  }

  function isInvalidToken(error: unknown): error is APNsError {
    return error instanceof APNsError && error.isInvalidToken;
  }

  async function sendDevice(
    token: string,
    bundleId: string,
    environment: APNsEnvironment,
    notification: DeviceNotification,
  ) {
    try {
      await provider().send({
        token,
        bundleId,
        environment,
        pushType: "alert",
        priority: 10,
        collapseId: notification.collapseId,
        expirationAt: notification.expirationAt,
        payload: deviceNotificationPayload(notification),
      });
    } catch (error) {
      if (isInvalidToken(error)) {
        void options.tokens
          .removeDeviceToken(token, bundleId, environment, error.invalidatedAt)
          .catch((cleanupError) => {
            console.error(
              "[notifications] invalid APNs token cleanup failed",
              cleanupError,
            );
          });
      }
      throw new NotificationDeliveryError(error);
    }
  }

  return {
    async sendToDevice(target, notification) {
      await sendDevice(
        target.deviceToken,
        target.bundleId,
        target.environment,
        notification,
      );
    },

    async sendToUser(userId, notification) {
      if (!options.tokens.listDevices) {
        throw new Error("The token store cannot list devices for a user.");
      }
      const devices = await options.tokens.listDevices(userId);
      const failures: unknown[] = [];
      await Promise.all(
        devices.map(async (device) => {
          try {
            await sendDevice(
              device.deviceToken,
              device.bundleId,
              device.environment,
              notification,
            );
          } catch (error) {
            failures.push(error);
          }
        }),
      );
      if (failures.length > 0) {
        throw new AggregateError(failures, "Notification fan-out failed.");
      }
    },
  };
}

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

export interface DeliveryReport {
  sent: number;
  failed: number;
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
  ): Promise<DeliveryReport>;
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
        payload: deviceNotificationPayload(notification),
      });
      return true;
    } catch (error) {
      if (isInvalidToken(error)) {
        await options.tokens.removeDeviceToken(token, bundleId, environment);
      }
      throw error;
    }
  }

  return {
    async sendToDevice(target, notification) {
      try {
        await sendDevice(
          target.deviceToken,
          target.bundleId,
          target.environment,
          notification,
        );
        return { sent: 1, failed: 0 };
      } catch {
        return { sent: 0, failed: 1 };
      }
    },
  };
}

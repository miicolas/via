import type { APNsEnvironment } from "@via/contract";

import {
  APNsError,
  type APNsProvider,
  deviceNotificationPayload,
  liveActivityPayload,
  type DeviceNotification,
  type JourneyActivityAttributesPayload,
  type JourneyActivityContentState,
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

export interface NotificationDelivery {
  sendToUser(
    userId: string,
    notification: DeviceNotification,
  ): Promise<DeliveryReport>;
  updateLiveActivity(
    activityId: string,
    contentState: JourneyActivityContentState,
    alert?: { title: string; body: string },
  ): Promise<boolean>;
  updateLiveActivitiesForJourney(
    journeyId: string,
    contentState: JourneyActivityContentState,
    alert?: { title: string; body: string },
  ): Promise<DeliveryReport>;
  endLiveActivity(
    activityId: string,
    contentState: JourneyActivityContentState,
    dismissalDate?: Date,
    alert?: { title: string; body: string },
  ): Promise<boolean>;
  endLiveActivitiesForJourney(
    journeyId: string,
    contentState: JourneyActivityContentState,
    dismissalDate?: Date,
    alert?: { title: string; body: string },
  ): Promise<DeliveryReport>;
  startLiveActivity(
    userId: string,
    attributes: JourneyActivityAttributesPayload,
    contentState: JourneyActivityContentState,
    alert?: { title: string; body: string },
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

  function report(results: PromiseSettledResult<boolean>[]): DeliveryReport {
    return {
      sent: results.filter((result) => result.status === "fulfilled").length,
      failed: results.filter((result) => result.status === "rejected").length,
    };
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

  async function sendActivity(
    activity: Awaited<ReturnType<NotificationTokenStore["getActivity"]>>,
    event: "update" | "end",
    contentState: JourneyActivityContentState,
    dismissalDate?: Date,
    alert?: { title: string; body: string },
  ): Promise<boolean> {
    if (!activity) return false;
    try {
      await provider().send({
        token: activity.activityToken,
        bundleId: activity.bundleId,
        environment: activity.environment,
        pushType: "liveactivity",
        priority: alert ? 10 : 5,
        collapseId: activity.activityId,
        payload: liveActivityPayload({
          event,
          contentState,
          dismissalDate,
          alert,
        }),
      });
    } catch (error) {
      if (isInvalidToken(error)) {
        await options.tokens.removeActivityToken(
          activity.activityToken,
          activity.bundleId,
          activity.environment,
        );
      }
      throw error;
    }
    return true;
  }

  return {
    async sendToUser(userId, notification) {
      const devices = await options.tokens.listDevices(userId);
      const results = await Promise.allSettled(
        devices.map((device) =>
          sendDevice(
            device.deviceToken,
            device.bundleId,
            device.environment,
            notification,
          ),
        ),
      );
      return {
        ...report(results),
      };
    },

    async updateLiveActivity(activityId, contentState, alert) {
      const activity = await options.tokens.getActivity(activityId);
      return sendActivity(activity, "update", contentState, undefined, alert);
    },

    async updateLiveActivitiesForJourney(journeyId, contentState, alert) {
      const activities = await options.tokens.listActivities(journeyId);
      const results = await Promise.allSettled(
        activities.map((activity) =>
          sendActivity(activity, "update", contentState, undefined, alert),
        ),
      );
      return report(results);
    },

    async endLiveActivity(activityId, contentState, dismissalDate, alert) {
      const activity = await options.tokens.getActivity(activityId);
      return sendActivity(activity, "end", contentState, dismissalDate, alert);
    },

    async endLiveActivitiesForJourney(
      journeyId,
      contentState,
      dismissalDate,
      alert,
    ) {
      const activities = await options.tokens.listActivities(journeyId);
      const results = await Promise.allSettled(
        activities.map((activity) =>
          sendActivity(activity, "end", contentState, dismissalDate, alert),
        ),
      );
      return report(results);
    },

    async startLiveActivity(userId, attributes, contentState, alert) {
      const startTokens = await options.tokens.getPushToStartTokens(userId);
      const results = await Promise.allSettled(
        startTokens.map(async (token) => {
          try {
            await provider().send({
              token: token.pushToStartToken,
              bundleId: token.bundleId,
              environment: token.environment,
              pushType: "liveactivity",
              priority: 10,
              payload: liveActivityPayload({
                event: "start",
                attributes,
                contentState,
                alert,
              }),
            });
          } catch (error) {
            if (isInvalidToken(error)) {
              await options.tokens.removePushToStartToken(
                token.pushToStartToken,
                token.bundleId,
                token.environment,
              );
            }
            throw error;
          }
          return true;
        }),
      );
      return report(results);
    },
  };
}

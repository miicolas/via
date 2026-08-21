import { expect, test } from "bun:test";

import {
  APNsError,
  type APNsProvider,
  type APNsRequest,
  type JourneyActivityContentState,
} from "./apns";
import { createNotificationDelivery } from "./delivery";
import type {
  NotificationDevice,
  NotificationLiveActivity,
  NotificationStartToken,
  NotificationTokenStore,
} from "./repository";

const now = new Date("2026-08-21T12:00:00Z");

const device: NotificationDevice = {
  installationId: "installation-1",
  userId: "user-1",
  deviceToken: "aa".repeat(32),
  bundleId: "dev.via.app",
  environment: "sandbox",
  appVersion: "1.0.2",
  osVersion: "26.0",
  createdAt: now,
  lastSeenAt: now,
};

const activity: NotificationLiveActivity = {
  activityId: "activity-1",
  userId: "user-1",
  installationId: "installation-1",
  journeyId: "journey-1",
  activityToken: "bb".repeat(32),
  bundleId: "dev.via.app",
  environment: "sandbox",
  createdAt: now,
  lastSeenAt: now,
};

const startToken: NotificationStartToken = {
  installationId: "installation-1",
  userId: "user-1",
  pushToStartToken: "cc".repeat(32),
  bundleId: "dev.via.app",
  environment: "sandbox",
  createdAt: now,
  lastSeenAt: now,
};

const contentState: JourneyActivityContentState = {
  phaseTitle: "En route",
  instructionTitle: "Nation",
  arrivalAt: now,
  isOffline: false,
  isArrived: false,
  progressFraction: 0.5,
};

function fakeStore() {
  const removed = {
    devices: [] as string[],
    activities: [] as string[],
    startTokens: [] as string[],
  };
  const store: NotificationTokenStore = {
    registerDevice: async () => {},
    unregisterDevice: async () => {},
    registerActivity: async () => {},
    unregisterActivity: async () => {},
    registerPushToStartToken: async () => {},
    listDevices: async (userId) => (userId === "user-1" ? [device] : []),
    getActivity: async (activityId) =>
      activityId === activity.activityId ? activity : null,
    listActivities: async (journeyId) =>
      journeyId === activity.journeyId ? [activity] : [],
    getPushToStartTokens: async (userId) =>
      userId === "user-1" ? [startToken] : [],
    removeDeviceToken: async (token) => {
      removed.devices.push(token);
    },
    removeActivityToken: async (token) => {
      removed.activities.push(token);
    },
    removePushToStartToken: async (token) => {
      removed.startTokens.push(token);
    },
  };
  return { store, removed };
}

function fakeProvider(requests: APNsRequest[]): APNsProvider {
  return {
    send: async (request) => {
      requests.push(request);
      return { apnsId: "apns-id" };
    },
  };
}

test("notification delivery fans out device pushes with the alert payload", async () => {
  const requests: APNsRequest[] = [];
  const { store } = fakeStore();
  const delivery = createNotificationDelivery({
    apns: fakeProvider(requests),
    tokens: store,
  });

  await expect(
    delivery.sendToUser("user-1", {
      title: "Via",
      body: "Le trajet est prêt.",
    }),
  ).resolves.toEqual({ sent: 1, failed: 0 });

  expect(requests[0]).toMatchObject({
    token: device.deviceToken,
    pushType: "alert",
    priority: 10,
    payload: {
      aps: {
        alert: { title: "Via", body: "Le trajet est prêt." },
        sound: "default",
      },
    },
  });
});

test("notification delivery uses the Live Activity lifecycle and priorities", async () => {
  const requests: APNsRequest[] = [];
  const { store } = fakeStore();
  const delivery = createNotificationDelivery({
    apns: fakeProvider(requests),
    tokens: store,
  });

  await expect(
    delivery.updateLiveActivity(activity.activityId, contentState, {
      title: "Retard",
      body: "Le train est retardé.",
    }),
  ).resolves.toBe(true);
  await expect(
    delivery.updateLiveActivitiesForJourney(activity.journeyId, contentState),
  ).resolves.toEqual({ sent: 1, failed: 0 });
  await expect(
    delivery.endLiveActivity(
      activity.activityId,
      contentState,
      new Date("2026-08-21T13:00:00Z"),
    ),
  ).resolves.toBe(true);
  await expect(
    delivery.endLiveActivitiesForJourney(
      activity.journeyId,
      contentState,
      new Date("2026-08-21T13:00:00Z"),
    ),
  ).resolves.toEqual({ sent: 1, failed: 0 });
  await expect(
    delivery.startLiveActivity(
      "user-1",
      { journeyID: "journey-1" },
      contentState,
    ),
  ).resolves.toEqual({ sent: 1, failed: 0 });

  expect(
    requests.map(({ payload, priority }) => ({
      event: (payload.aps as Record<string, unknown>).event,
      priority,
    })),
  ).toEqual([
    { event: "update", priority: 10 },
    { event: "update", priority: 5 },
    { event: "end", priority: 5 },
    { event: "end", priority: 5 },
    { event: "start", priority: 10 },
  ]);
  expect((requests[0].payload.aps as Record<string, unknown>).event).toBe(
    "update",
  );
  expect((requests[2].payload.aps as Record<string, unknown>).event).toBe(
    "end",
  );
  expect((requests[4].payload.aps as Record<string, unknown>).event).toBe(
    "start",
  );
});

test("invalid APNs tokens are removed while the delivery report remains partial", async () => {
  const { store, removed } = fakeStore();
  const apns: APNsProvider = {
    send: async () => {
      throw new APNsError(410, "Unregistered", "gone");
    },
  };
  const delivery = createNotificationDelivery({ apns, tokens: store });

  await expect(
    delivery.sendToUser("user-1", { title: "Via", body: "Test" }),
  ).resolves.toEqual({
    sent: 0,
    failed: 1,
  });
  expect(removed.devices).toEqual([device.deviceToken]);
});

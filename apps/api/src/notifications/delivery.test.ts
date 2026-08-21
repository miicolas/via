import { expect, test } from "bun:test";

import { APNsError, type APNsProvider, type APNsRequest } from "./apns";
import { createNotificationDelivery } from "./delivery";
import type { NotificationDevice, NotificationTokenStore } from "./repository";

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

function fakeStore() {
  const removed = {
    devices: [] as string[],
  };
  const store: NotificationTokenStore = {
    registerDevice: async () => {},
    unregisterDevice: async () => {},
    registerActivity: async () => {},
    unregisterActivity: async () => {},
    registerPushToStartToken: async () => {},
    removeDeviceToken: async (token) => {
      removed.devices.push(token);
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

test("notification delivery sends a device push with the alert payload", async () => {
  const requests: APNsRequest[] = [];
  const { store } = fakeStore();
  const delivery = createNotificationDelivery({
    apns: fakeProvider(requests),
    tokens: store,
  });

  await expect(
    delivery.sendToDevice(device, {
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

test("invalid APNs tokens are removed while the delivery report remains partial", async () => {
  const { store, removed } = fakeStore();
  const apns: APNsProvider = {
    send: async () => {
      throw new APNsError(410, "Unregistered", "gone");
    },
  };
  const delivery = createNotificationDelivery({ apns, tokens: store });

  await expect(
    delivery.sendToDevice(device, { title: "Via", body: "Test" }),
  ).resolves.toEqual({
    sent: 0,
    failed: 1,
  });
  expect(removed.devices).toEqual([device.deviceToken]);
});

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
    devices: [] as Array<{ token: string; invalidatedAt?: Date }>,
  };
  const store: NotificationTokenStore = {
    registerDevice: async () => {},
    unregisterDevice: async () => {},
    removeDeviceToken: async (
      token,
      _bundleId,
      _environment,
      invalidatedAt,
    ) => {
      removed.devices.push({ token, invalidatedAt });
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
  ).resolves.toBeUndefined();

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

test("invalid APNs tokens are conditionally removed and the permanent error surfaces", async () => {
  const { store, removed } = fakeStore();
  const invalidatedAt = new Date("2026-08-21T11:59:00Z");
  const apns: APNsProvider = {
    send: async () => {
      throw new APNsError(410, "Unregistered", "gone", invalidatedAt);
    },
  };
  const delivery = createNotificationDelivery({ apns, tokens: store });

  await expect(
    delivery.sendToDevice(device, { title: "Via", body: "Test" }),
  ).rejects.toMatchObject({ retryable: false });
  await new Promise((resolve) => setTimeout(resolve, 0));
  expect(removed.devices).toEqual([
    { token: device.deviceToken, invalidatedAt },
  ]);
});

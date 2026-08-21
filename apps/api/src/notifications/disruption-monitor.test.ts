import { expect, test } from "bun:test";

import { fakeRedis } from "../routers/departures/__fixtures__/fake-redis";
import type { DisruptionsSnapshot } from "../routers/lines/disruptions/snapshot";
import type { NormalizedDisruption } from "../routers/lines/disruptions/parse";
import type { DeviceNotification } from "./apns";
import type { NotificationDelivery } from "./delivery";
import {
  NotificationDisruptionMonitor,
  journeyDisruptionMatches,
} from "./disruption-monitor";
import type {
  NotificationJourneyRecipient,
  NotificationJourneySubscriptionStore,
} from "./journey-subscriptions";

const now = new Date("2026-08-21T12:00:00Z");

function subscription(overrides: Partial<NotificationJourneyRecipient> = {}) {
  return {
    installationId: "installation-1",
    userId: "user-1",
    journeyId: "journey-1",
    routeIds: ["IDFM:C01371"],
    startsAt: new Date("2026-08-21T11:55:00Z"),
    endsAt: new Date("2026-08-21T13:00:00Z"),
    createdAt: now,
    lastSeenAt: now,
    deviceToken: "aa".repeat(32),
    bundleId: "dev.via.app",
    environment: "sandbox" as const,
    ...overrides,
  } satisfies NotificationJourneyRecipient;
}

const disruption = {
  id: "disruption-1",
  severity: "disrupted" as const,
  title: "Ligne perturbée",
  message: "Un incident ralentit la ligne.",
  routeIds: ["IDFM:C01371"],
  periods: [
    {
      beginsAt: Math.floor(Date.parse("2026-08-21T11:00:00Z") / 1_000),
      endsAt: Math.floor(Date.parse("2026-08-21T13:00:00Z") / 1_000),
    },
  ],
  impactedSections: [],
  updatedAt: 1,
};

function storeFor(value: NotificationJourneyRecipient) {
  return storeForMany([value]);
}

function storeForMany(subscriptions: NotificationJourneyRecipient[]) {
  const store: NotificationJourneySubscriptionStore = {
    register: async () => {},
    unregister: async () => {},
    listActiveBatch: async (_now, afterInstallationId, limit) =>
      subscriptions
        .filter(
          (item) =>
            !afterInstallationId || item.installationId > afterInstallationId,
        )
        .slice(0, limit),
    deleteExpired: async () => {},
  };
  return store;
}

function deliveryFor(
  reports: Array<{ deviceToken: string; notification: DeviceNotification }>,
  result: { sent: number; failed: number } = { sent: 1, failed: 0 },
): NotificationDelivery {
  return {
    sendToDevice: async (target, notification) => {
      reports.push({ deviceToken: target.deviceToken, notification });
      return result;
    },
  };
}

function snapshot(
  value: NormalizedDisruption = disruption,
): DisruptionsSnapshot {
  return { disruptions: [value], fetchedAt: Math.floor(now.getTime() / 1_000) };
}

test("only a matching line inside both active windows is eligible", () => {
  expect(journeyDisruptionMatches(subscription(), disruption, now)).toBe(true);
  expect(
    journeyDisruptionMatches(
      subscription({ routeIds: ["IDFM:C01234"] }),
      disruption,
      now,
    ),
  ).toBe(false);
  expect(
    journeyDisruptionMatches(
      subscription({ endsAt: new Date("2026-08-21T11:59:00Z") }),
      disruption,
      now,
    ),
  ).toBe(false);
});

test("the monitor deduplicates one disruption version and sends aggravations", async () => {
  const { client } = fakeRedis();
  const reports: Array<{
    deviceToken: string;
    notification: DeviceNotification;
  }> = [];
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeFor(subscription()),
    delivery: deliveryFor(reports),
    snapshot: async () => snapshot(),
    now: () => now,
  });

  await monitor.pollOnce();
  await monitor.pollOnce();
  expect(reports).toHaveLength(1);
  expect(reports[0]?.notification.data).toMatchObject({
    type: "journey",
    journeyId: "journey-1",
    deepLink: "via://journey?journeyId=journey-1&mode=active",
  });

  await monitor.pollOnce();
  expect(reports).toHaveLength(1);
  const aggravated = {
    ...disruption,
    severity: "suspended" as const,
    updatedAt: 2,
  };
  const aggravatedMonitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeFor(subscription()),
    delivery: deliveryFor(reports),
    snapshot: async () => snapshot(aggravated),
    now: () => now,
  });
  await aggravatedMonitor.pollOnce();
  expect(reports).toHaveLength(2);
});

test("a held Redis lock skips the poll and APNs failure remains retryable", async () => {
  const { client, store } = fakeRedis();
  store.set("notifications:disruption-monitor:lock", "1");
  const reports: Array<{
    deviceToken: string;
    notification: DeviceNotification;
  }> = [];
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeFor(subscription()),
    delivery: deliveryFor(reports, { sent: 0, failed: 1 }),
    snapshot: async () => snapshot(),
    now: () => now,
  });

  await monitor.pollOnce();
  expect(reports).toHaveLength(0);
  store.delete("notifications:disruption-monitor:lock");
  await monitor.pollOnce();
  await monitor.pollOnce();
  expect(reports).toHaveLength(2);
});

test("the monitor pages recipients and targets each subscribed installation once", async () => {
  const recipients = Array.from({ length: 251 }, (_, index) => {
    const suffix = String(index).padStart(3, "0");
    return subscription({
      installationId: `installation-${suffix}`,
      deviceToken: `${suffix}`.padEnd(64, "a"),
    });
  });
  const { client } = fakeRedis();
  const reports: Array<{
    deviceToken: string;
    notification: DeviceNotification;
  }> = [];
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeForMany(recipients),
    delivery: deliveryFor(reports),
    snapshot: async () => snapshot(),
    now: () => now,
  });

  await monitor.pollOnce();

  expect(reports).toHaveLength(251);
  expect(new Set(reports.map((report) => report.deviceToken)).size).toBe(251);
});

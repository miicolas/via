import { expect, test } from "bun:test";

import { fakeRedis } from "../routers/departures/__fixtures__/fake-redis";
import type { DisruptionsSnapshot } from "../routers/lines/disruptions/snapshot";
import type { NormalizedDisruption } from "../routers/lines/disruptions/parse";
import { APNsError, type DeviceNotification } from "./apns";
import {
  NotificationDeliveryError,
  type NotificationDelivery,
} from "./delivery";
import {
  NotificationDisruptionMonitor,
  journeyDisruptionMatches,
  journeyDisruptionNotification,
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
    routeWindows: [
      {
        routeId: "IDFM:C01371",
        startsAt: Math.floor(Date.parse("2026-08-21T11:55:00Z") / 1_000),
        endsAt: Math.floor(Date.parse("2026-08-21T13:00:00Z") / 1_000),
      },
    ],
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
    hasActive: async () => subscriptions.length > 0,
    listActiveBatch: async (_now, afterInstallationId, limit) =>
      subscriptions
        .filter(
          (item) =>
            !afterInstallationId || item.installationId > afterInstallationId,
        )
        .slice(0, limit),
    filterCurrentBatch: async (recipients) => [...recipients],
    deleteExpiredBatch: async () => 0,
  };
  return store;
}

function deliveryFor(
  reports: Array<{ deviceToken: string; notification: DeviceNotification }>,
): NotificationDelivery {
  return {
    sendToDevice: async (target, notification) => {
      reports.push({ deviceToken: target.deviceToken, notification });
    },
  };
}

function snapshot(
  value: NormalizedDisruption = disruption,
): DisruptionsSnapshot {
  return { disruptions: [value], fetchedAt: Math.floor(now.getTime() / 1_000) };
}

test("the monitor does not load disruptions without an active journey", async () => {
  const { client } = fakeRedis();
  let snapshotLoads = 0;
  let cleanups = 0;
  const subscriptions = storeForMany([]);
  subscriptions.deleteExpiredBatch = async () => {
    cleanups += 1;
    return 0;
  };
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions,
    delivery: deliveryFor([]),
    snapshot: async () => {
      snapshotLoads += 1;
      return snapshot();
    },
    now: () => now,
    shardCount: 1,
  });

  await monitor.pollOnce();

  expect(snapshotLoads).toBe(0);
  expect(cleanups).toBe(1);
});

test("only a matching line inside both active windows is eligible", () => {
  expect(journeyDisruptionMatches(subscription(), disruption, now)).toBe(true);
  expect(
    journeyDisruptionMatches(
      subscription({
        routeWindows: [
          {
            routeId: "IDFM:C01234",
            startsAt: Math.floor(Date.parse("2026-08-21T11:55:00Z") / 1_000),
            endsAt: Math.floor(Date.parse("2026-08-21T13:00:00Z") / 1_000),
          },
        ],
      }),
      disruption,
      now,
    ),
  ).toBe(false);
  expect(
    journeyDisruptionMatches(
      subscription({
        routeWindows: [
          {
            routeId: "IDFM:C01371",
            startsAt: Math.floor(Date.parse("2026-08-21T12:20:00Z") / 1_000),
            endsAt: Math.floor(Date.parse("2026-08-21T12:40:00Z") / 1_000),
          },
        ],
      }),
      disruption,
      now,
    ),
  ).toBe(true);
  expect(
    journeyDisruptionMatches(
      subscription({ endsAt: new Date("2026-08-21T11:59:00Z") }),
      disruption,
      now,
    ),
  ).toBe(false);
  expect(
    journeyDisruptionMatches(
      subscription({
        routeWindows: [
          {
            routeId: "IDFM:C01371",
            startsAt: Math.floor(Date.parse("2026-08-21T10:00:00Z") / 1_000),
            endsAt: Math.floor(Date.parse("2026-08-21T11:30:00Z") / 1_000),
          },
        ],
      }),
      disruption,
      now,
    ),
  ).toBe(false);
});

test("notification payloads are bounded and collapse IDs include both identifiers", () => {
  const longJourney = "journey-".padEnd(500, "x");
  const first = journeyDisruptionNotification(
    subscription({ journeyId: longJourney }),
    {
      ...disruption,
      id: "incident-a",
      title: "🚇".repeat(1_000),
      message: "é".repeat(5_000),
    },
    now,
  );
  const second = journeyDisruptionNotification(
    subscription({ journeyId: longJourney }),
    { ...disruption, id: "incident-b" },
    now,
  );

  expect(first.collapseId.length).toBeLessThanOrEqual(64);
  expect(first.collapseId).not.toBe(second.collapseId);
  expect(first.expirationAt).toEqual(new Date("2026-08-21T13:00:00Z"));
  expect(
    new TextEncoder().encode(JSON.stringify(first)).byteLength,
  ).toBeLessThan(4_096);
});

test("notification expiration covers overlapping active disruption periods", () => {
  const notification = journeyDisruptionNotification(
    subscription({ endsAt: new Date("2026-08-21T15:00:00Z") }),
    {
      ...disruption,
      periods: [
        {
          beginsAt: Math.floor(Date.parse("2026-08-21T11:00:00Z") / 1_000),
          endsAt: Math.floor(Date.parse("2026-08-21T12:30:00Z") / 1_000),
        },
        {
          beginsAt: Math.floor(Date.parse("2026-08-21T11:30:00Z") / 1_000),
          endsAt: Math.floor(Date.parse("2026-08-21T14:00:00Z") / 1_000),
        },
      ],
    },
    now,
  );

  expect(notification.expirationAt).toEqual(new Date("2026-08-21T14:00:00Z"));
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
    shardCount: 1,
  });

  await monitor.pollOnce();
  await monitor.pollOnce();
  expect(reports).toHaveLength(1);
  expect(reports[0]?.notification.data).toMatchObject({
    type: "journey",
    journeyId: "journey-1",
    mode: "active",
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
    now: () => new Date(now.getTime() + 2 * 60 * 1_000),
    shardCount: 1,
  });
  await aggravatedMonitor.pollOnce();
  expect(reports).toHaveLength(2);
});

test("a transient APNs failure opens a circuit instead of retry-storming", async () => {
  const { client, store } = fakeRedis();
  const reports: Array<{
    deviceToken: string;
    notification: DeviceNotification;
  }> = [];
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeFor(subscription()),
    delivery: {
      sendToDevice: async (target, notification) => {
        reports.push({ deviceToken: target.deviceToken, notification });
        throw new NotificationDeliveryError(new Error("network"));
      },
    },
    snapshot: async () => snapshot(),
    now: () => now,
    shardCount: 1,
  });

  await monitor.pollOnce();
  await monitor.pollOnce();
  expect(reports).toHaveLength(1);
  expect(store.get("notifications:apns:circuit")).toBe(1);
});

test("a provider configuration failure opens the circuit without deduplicating", async () => {
  const { client, store } = fakeRedis();
  const reports: Array<{
    deviceToken: string;
    notification: DeviceNotification;
  }> = [];
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeFor(subscription()),
    delivery: {
      sendToDevice: async (target, notification) => {
        reports.push({ deviceToken: target.deviceToken, notification });
        throw new NotificationDeliveryError(
          new APNsError(403, "InvalidProviderToken", null),
        );
      },
    },
    snapshot: async () => snapshot(),
    now: () => now,
    shardCount: 1,
  });

  await monitor.pollOnce();

  expect(reports).toHaveLength(1);
  expect(store.get("notifications:apns:circuit")).toBe(1);
  expect(
    [...store.keys()].some(
      (key) =>
        key.includes("notifications:disruption:") && !key.endsWith(":claim"),
    ),
  ).toBe(false);
});

test("device throttling remains local and retryable without opening the circuit", async () => {
  const { client, store } = fakeRedis();
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeFor(subscription()),
    delivery: {
      sendToDevice: async () => {
        throw new NotificationDeliveryError(
          new APNsError(429, "TooManyRequests", null),
        );
      },
    },
    snapshot: async () => snapshot(),
    now: () => now,
    shardCount: 1,
  });

  await monitor.pollOnce();

  expect(store.get("notifications:apns:circuit")).toBeUndefined();
  expect(
    [...store.keys()].some(
      (key) =>
        key.includes("notifications:disruption:") && !key.endsWith(":claim"),
    ),
  ).toBe(false);
});

test("a request-wide APNs rejection opens the circuit without deduplicating", async () => {
  const { client, store } = fakeRedis();
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeFor(subscription()),
    delivery: {
      sendToDevice: async () => {
        throw new NotificationDeliveryError(
          new APNsError(400, "PayloadTooLarge", null),
        );
      },
    },
    snapshot: async () => snapshot(),
    now: () => now,
    shardCount: 1,
  });

  await monitor.pollOnce();

  expect(store.get("notifications:apns:circuit")).toBe(1);
  expect(
    [...store.keys()].some(
      (key) =>
        key.includes("notifications:disruption:") && !key.endsWith(":claim"),
    ),
  ).toBe(false);
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
    shardCount: 1,
  });

  await monitor.pollOnce();

  expect(reports).toHaveLength(251);
  expect(new Set(reports.map((report) => report.deviceToken)).size).toBe(251);
});

test("post-claim revalidation stays one query per wave when Redis replies are staggered", async () => {
  const recipients = Array.from({ length: 25 }, (_, index) =>
    subscription({
      installationId: `installation-${String(index).padStart(2, "0")}`,
      deviceToken: String(index).padStart(64, "a"),
    }),
  );
  const { client } = fakeRedis();
  const originalClaim = client.claimNotification;
  let claimIndex = 0;
  client.claimNotification = async (input) => {
    const delay = claimIndex;
    claimIndex += 1;
    await new Promise((resolve) => setTimeout(resolve, delay));
    return originalClaim(input);
  };
  let validations = 0;
  const store = storeForMany(recipients);
  store.filterCurrentBatch = async (batch) => {
    validations += 1;
    return [...batch];
  };
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: store,
    delivery: deliveryFor([]),
    snapshot: async () => snapshot(),
    now: () => now,
    shardCount: 1,
  });

  await monitor.pollOnce();

  expect(validations).toBe(2);
});

test("a recipient changed after claim is dropped before APNs delivery", async () => {
  const { client } = fakeRedis();
  const recipient = subscription();
  const store = storeFor(recipient);
  let validations = 0;
  store.filterCurrentBatch = async (batch) => {
    validations += 1;
    return validations === 1 ? [...batch] : [];
  };
  const reports: Array<{
    deviceToken: string;
    notification: DeviceNotification;
  }> = [];
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: store,
    delivery: deliveryFor(reports),
    snapshot: async () => snapshot(),
    now: () => now,
    shardCount: 1,
  });

  await monitor.pollOnce();

  expect(reports).toHaveLength(0);
  expect(validations).toBe(2);
});

test("a partially failed claim batch releases only its owned claims and leases", async () => {
  const recipients = [
    subscription({ installationId: "installation-a" }),
    subscription({
      installationId: "installation-b",
      deviceToken: "bb".repeat(32),
    }),
  ];
  const { client, store } = fakeRedis();
  const originalClaim = client.claimNotification;
  let calls = 0;
  client.claimNotification = async (input) => {
    calls += 1;
    const result = await originalClaim(input);
    if (calls === 2) throw new Error("connection lost after EVAL");
    return result;
  };
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeForMany(recipients),
    delivery: deliveryFor([]),
    snapshot: async () => snapshot(),
    now: () => now,
    shardCount: 1,
  });

  await monitor.pollOnce();

  expect(
    [...store.keys()].filter(
      (key) => key.endsWith(":claim") || key.endsWith(":delivery-lease"),
    ),
  ).toEqual([]);
});

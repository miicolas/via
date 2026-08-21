import { expect, test } from 'bun:test';

import { fakeRedis } from '../routers/departures/__fixtures__/fake-redis';
import type { DisruptionsSnapshot } from '../routers/lines/disruptions/snapshot';
import type { NormalizedDisruption } from '../routers/lines/disruptions/parse';
import type { DeviceNotification } from './apns';
import type { NotificationDelivery } from './delivery';
import {
  NotificationDisruptionMonitor,
  journeyDisruptionMatches,
} from './disruption-monitor';
import type {
  NotificationJourneySubscription,
  NotificationJourneySubscriptionStore,
} from './journey-subscriptions';

const now = new Date('2026-08-21T12:00:00Z');

function subscription(overrides: Partial<NotificationJourneySubscription> = {}) {
  return {
    installationId: 'installation-1',
    userId: 'user-1',
    journeyId: 'journey-1',
    routeIds: ['IDFM:C01371'],
    startsAt: new Date('2026-08-21T11:55:00Z'),
    endsAt: new Date('2026-08-21T13:00:00Z'),
    createdAt: now,
    lastSeenAt: now,
    ...overrides,
  } satisfies NotificationJourneySubscription;
}

const disruption = {
  id: 'disruption-1',
  severity: 'disrupted' as const,
  title: 'Ligne perturbée',
  message: 'Un incident ralentit la ligne.',
  routeIds: ['IDFM:C01371'],
  periods: [
    {
      beginsAt: Math.floor(Date.parse('2026-08-21T11:00:00Z') / 1_000),
      endsAt: Math.floor(Date.parse('2026-08-21T13:00:00Z') / 1_000),
    },
  ],
  impactedSections: [],
  updatedAt: 1,
};

function storeFor(value: NotificationJourneySubscription) {
  let subscriptions = [value];
  const store: NotificationJourneySubscriptionStore = {
    register: async () => {},
    unregister: async () => {},
    listActive: async () => subscriptions,
    deleteExpired: async () => 0,
    removeInstallation: async () => {
      subscriptions = [];
    },
  };
  return store;
}

function deliveryFor(
  reports: Array<{ userId: string; notification: DeviceNotification }>,
  result: { sent: number; failed: number } = { sent: 1, failed: 0 },
): NotificationDelivery {
  return {
    sendToUser: async (userId, notification) => {
      reports.push({ userId, notification });
      return result;
    },
    updateLiveActivity: async () => false,
    updateLiveActivitiesForJourney: async () => ({ sent: 0, failed: 0 }),
    endLiveActivity: async () => false,
    endLiveActivitiesForJourney: async () => ({ sent: 0, failed: 0 }),
    startLiveActivity: async () => ({ sent: 0, failed: 0 }),
  };
}

function snapshot(value: NormalizedDisruption = disruption): DisruptionsSnapshot {
  return { disruptions: [value], fetchedAt: Math.floor(now.getTime() / 1_000) };
}

test('only a matching line inside both active windows is eligible', () => {
  expect(journeyDisruptionMatches(subscription(), disruption, now)).toBe(true);
  expect(
    journeyDisruptionMatches(
      subscription({ routeIds: ['IDFM:C01234'] }),
      disruption,
      now,
    ),
  ).toBe(false);
  expect(
    journeyDisruptionMatches(
      subscription({ endsAt: new Date('2026-08-21T11:59:00Z') }),
      disruption,
      now,
    ),
  ).toBe(false);
});

test('the monitor deduplicates one disruption version and sends aggravations', async () => {
  const { client } = fakeRedis();
  const reports: Array<{ userId: string; notification: DeviceNotification }> = [];
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
    type: 'journey',
    journeyId: 'journey-1',
    deepLink: 'via://journey?journeyId=journey-1&mode=active',
  });

  await monitor.pollOnce();
  expect(reports).toHaveLength(1);
  const aggravated = { ...disruption, severity: 'suspended' as const, updatedAt: 2 };
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

test('a held Redis lock skips the poll and APNs failure remains retryable', async () => {
  const { client, store } = fakeRedis();
  store.set('notifications:disruption-monitor:lock', '1');
  const reports: Array<{ userId: string; notification: DeviceNotification }> = [];
  const monitor = new NotificationDisruptionMonitor({
    redis: client,
    subscriptions: storeFor(subscription()),
    delivery: deliveryFor(reports, { sent: 0, failed: 1 }),
    snapshot: async () => snapshot(),
    now: () => now,
  });

  await monitor.pollOnce();
  expect(reports).toHaveLength(0);
  store.delete('notifications:disruption-monitor:lock');
  await monitor.pollOnce();
  await monitor.pollOnce();
  expect(reports).toHaveLength(2);
});

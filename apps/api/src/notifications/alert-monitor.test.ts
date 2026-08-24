import { expect, test } from 'bun:test';

import { fakeRedis } from '../routers/departures/__fixtures__/fake-redis';
import { NotificationAlertMonitor } from './alert-monitor';

const now = new Date('2026-08-24T12:00:00Z');

function alertSubscription(overrides: Partial<ReturnType<typeof baseAlertSubscription>> = {}) {
  return { ...baseAlertSubscription(), ...overrides };
}

function baseAlertSubscription() {
  return {
    id: 'alert-1',
    userId: 'user-1',
    topicKind: 'line' as const,
    topicId: 'IDFM:C01371',
    label: 'Ligne 1',
    daysOfWeek: [1],
    windows: [{ startMinute: 7 * 60, endMinute: 8 * 60 }],
    minimumSeverity: 'attention' as const,
    enabled: true,
    savedAt: now.toISOString(),
    updatedAt: now.toISOString(),
    deletedAt: undefined,
  };
}

test('the alert monitor does not load disruptions without an eligible alert', async () => {
  const { client } = fakeRedis();
  let snapshotLoads = 0;
  const monitor = new NotificationAlertMonitor({
    redis: client,
    subscriptions: {
      listActive: async () => [],
      listForTopic: async () => [],
    },
    lineState: {
      get: async () => new Set(),
      set: async () => {},
    },
    inbox: {
      insert: async () => 'inbox-item',
      list: async () => ({ items: [], unreadCount: 0 }),
      markRead: async () => {},
      unreadCount: async () => 0,
      sentToday: async () => 0,
    },
    delivery: { sendToDevice: async () => {} },
    snapshot: async () => {
      snapshotLoads += 1;
      return { disruptions: [], fetchedAt: Math.floor(now.getTime() / 1_000) };
    },
    preferences: async () => null,
    now: () => now,
  });

  await monitor.pollOnce();

  expect(snapshotLoads).toBe(0);
});

test('the alert monitor does not load disruptions outside every declared window', async () => {
  const { client } = fakeRedis();
  let snapshotLoads = 0;
  const monitor = new NotificationAlertMonitor({
    redis: client,
    subscriptions: {
      listActive: async (kind) => kind === 'line' ? [alertSubscription()] : [],
      listForTopic: async () => [],
    },
    lineState: {
      get: async () => new Set(),
      set: async () => {},
    },
    inbox: {
      insert: async () => 'inbox-item',
      list: async () => ({ items: [], unreadCount: 0 }),
      markRead: async () => {},
      unreadCount: async () => 0,
      sentToday: async () => 0,
    },
    delivery: { sendToDevice: async () => {} },
    snapshot: async () => {
      snapshotLoads += 1;
      return { disruptions: [], fetchedAt: Math.floor(now.getTime() / 1_000) };
    },
    preferences: async () => null,
    now: () => now,
  });

  await monitor.pollOnce();

  expect(snapshotLoads).toBe(0);
});

test('the alert monitor loads one snapshot when an alert is currently eligible', async () => {
  const { client } = fakeRedis();
  let snapshotLoads = 0;
  const monitor = new NotificationAlertMonitor({
    redis: client,
    subscriptions: {
      listActive: async (kind) => kind === 'line'
        ? [alertSubscription({ windows: [{ startMinute: 13 * 60, endMinute: 15 * 60 }] })]
        : [],
      listForTopic: async () => [],
    },
    lineState: {
      get: async () => new Set(),
      set: async () => {},
    },
    inbox: {
      insert: async () => 'inbox-item',
      list: async () => ({ items: [], unreadCount: 0 }),
      markRead: async () => {},
      unreadCount: async () => 0,
      sentToday: async () => 0,
    },
    delivery: { sendToDevice: async () => {} },
    snapshot: async () => {
      snapshotLoads += 1;
      return { disruptions: [], fetchedAt: Math.floor(now.getTime() / 1_000) };
    },
    preferences: async () => null,
    now: () => now,
  });

  await monitor.pollOnce();

  expect(snapshotLoads).toBe(1);
});

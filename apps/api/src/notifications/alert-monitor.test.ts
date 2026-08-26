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
      get: async () => ({ disruptionIds: new Set(), subscriptionIds: new Set(), missingCycles: new Map() }),
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
      get: async () => ({ disruptionIds: new Set(), subscriptionIds: new Set(), missingCycles: new Map() }),
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
      get: async () => ({ disruptionIds: new Set(), subscriptionIds: new Set(), missingCycles: new Map() }),
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

test('the alert monitor does not consume a disruption before its line alert is active', async () => {
  const { client } = fakeRedis();
  const initialNow = new Date('2026-08-24T12:00:00Z');
  let currentNow = initialNow;
  let poll = 0;
  let deliveries = 0;
  const states = new Map<string, {
    disruptionIds: Set<string>;
    subscriptionIds: Set<string>;
    missingCycles: Map<string, number>;
  }>();
  const disruption = {
    id: 'disruption-rer-a-1',
    severity: 'disrupted' as const,
    title: 'RER A : perturbation',
    message: 'Le trafic est perturbé.',
    routeIds: ['IDFM:C01742'],
    periods: [],
    impactedSections: [],
  };
  states.set('IDFM:C01742', {
    disruptionIds: new Set([disruption.id]),
    subscriptionIds: new Set(['alert-before']),
    missingCycles: new Map(),
  });
  const monitor = new NotificationAlertMonitor({
    redis: client,
    subscriptions: {
      listActive: async (kind) => {
        if (kind !== 'line') return [];
        poll += 1;
        return [alertSubscription({
          topicId: poll === 1 ? 'IDFM:C01371' : 'IDFM:C01742',
          label: poll === 1 ? 'Ligne 1' : 'RER A',
          windows: [{ startMinute: 0, endMinute: 1_439 }],
        })];
      },
      listForTopic: async () => [],
    },
    lineState: {
      get: async (routeId) => states.get(routeId) ?? {
        disruptionIds: new Set(),
        subscriptionIds: new Set(),
        missingCycles: new Map(),
      },
      set: async (routeId, state) => {
        states.set(routeId, {
          disruptionIds: new Set(state.disruptionIds),
          subscriptionIds: new Set(state.subscriptionIds),
          missingCycles: new Map(state.missingCycles),
        });
      },
    },
    inbox: {
      insert: async () => 'inbox-item',
      list: async () => ({ items: [], unreadCount: 0 }),
      markRead: async () => {},
      unreadCount: async () => 0,
      sentToday: async () => 0,
    },
    delivery: {
      sendToDevice: async () => {},
      sendToUser: async () => {
        deliveries += 1;
      },
    },
    snapshot: async () => ({
      disruptions: [disruption],
      fetchedAt: Math.floor(currentNow.getTime() / 1_000),
    }),
    preferences: async () => null,
    now: () => currentNow,
  });

  await monitor.pollOnce();
  currentNow = new Date(initialNow.getTime() + 121_000);
  await monitor.pollOnce();

  expect(deliveries).toBe(1);
});

test('the alert monitor sends one notification for duplicate PRIM content', async () => {
  const { client } = fakeRedis();
  let deliveries = 0;
  const titles: string[] = [];
  const shared = {
    severity: 'disrupted' as const,
    title: 'RER A : perturbation',
    message: 'Le trafic est perturbé.',
    routeIds: ['IDFM:C01742'],
    periods: [],
    impactedSections: [],
  };
  const monitor = new NotificationAlertMonitor({
    redis: client,
    subscriptions: {
      listActive: async (kind) => kind === 'line'
        ? [alertSubscription({
            topicId: 'IDFM:C01742',
            label: 'RER A',
            windows: [{ startMinute: 0, endMinute: 1_439 }],
          })]
        : [],
      listForTopic: async () => [],
    },
    lineState: {
      get: async () => ({ disruptionIds: new Set(), subscriptionIds: new Set(), missingCycles: new Map() }),
      set: async () => {},
    },
    inbox: {
      insert: async () => 'inbox-item',
      list: async () => ({ items: [], unreadCount: 0 }),
      markRead: async () => {},
      unreadCount: async () => 0,
      sentToday: async () => 0,
    },
    delivery: {
      sendToDevice: async () => {},
      sendToUser: async (_userId, notification) => {
        deliveries += 1;
        titles.push(notification.title);
      },
    },
    snapshot: async () => ({
      disruptions: [
        { ...shared, id: 'duplicate-event-1' },
        { ...shared, id: 'duplicate-event-2' },
      ],
      fetchedAt: Math.floor(now.getTime() / 1_000),
    }),
    preferences: async () => null,
    now: () => new Date('2026-08-24T12:00:00Z'),
  });

  await monitor.pollOnce();

  expect(deliveries).toBe(1);
  expect(titles).toEqual(['Perturbation · RER A']);
});

test('the alert monitor waits for a confirmed disappearance before sending restored', async () => {
  const { client } = fakeRedis();
  const initialNow = new Date('2026-08-24T12:00:00Z');
  let currentNow = initialNow;
  let snapshotIndex = 0;
  let deliveries = 0;
  const states = new Map<string, {
    disruptionIds: Set<string>;
    subscriptionIds: Set<string>;
    missingCycles: Map<string, number>;
  }>();
  const disruption = {
    id: 'disruption-metro-1-1',
    severity: 'disrupted' as const,
    title: 'Métro 1 : perturbation',
    message: 'Le trafic est perturbé.',
    routeIds: ['IDFM:C01371'],
    periods: [],
    impactedSections: [],
  };
  const snapshots = [[disruption], [], []];
  const monitor = new NotificationAlertMonitor({
    redis: client,
    subscriptions: {
      listActive: async (kind) => kind === 'line'
        ? [alertSubscription({
            topicId: 'IDFM:C01371',
            label: 'Métro 1',
            windows: [{ startMinute: 0, endMinute: 1_439 }],
          })]
        : [],
      listForTopic: async () => [],
    },
    lineState: {
      get: async (routeId) => states.get(routeId) ?? {
        disruptionIds: new Set(),
        subscriptionIds: new Set(),
        missingCycles: new Map(),
      },
      set: async (routeId, state) => {
        states.set(routeId, {
          disruptionIds: new Set(state.disruptionIds),
          subscriptionIds: new Set(state.subscriptionIds),
          missingCycles: new Map(state.missingCycles),
        });
      },
    },
    inbox: {
      insert: async () => 'inbox-item',
      list: async () => ({ items: [], unreadCount: 0 }),
      markRead: async () => {},
      unreadCount: async () => 0,
      sentToday: async () => 0,
    },
    delivery: {
      sendToDevice: async () => {},
      sendToUser: async () => {
        deliveries += 1;
      },
    },
    snapshot: async () => ({
      disruptions: snapshots[snapshotIndex++] ?? [],
      fetchedAt: Math.floor(currentNow.getTime() / 1_000),
    }),
    preferences: async () => null,
    now: () => currentNow,
  });

  await monitor.pollOnce();
  currentNow = new Date(initialNow.getTime() + 121_000);
  await monitor.pollOnce();
  expect(deliveries).toBe(1);

  currentNow = new Date(initialNow.getTime() + 242_000);
  await monitor.pollOnce();

  expect(deliveries).toBe(2);
});

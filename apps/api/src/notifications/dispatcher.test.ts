import { expect, test } from 'bun:test';

import { APNsError } from './apns';
import { NotificationDeliveryError, type NotificationDelivery } from './delivery';
import { NotificationDispatcher } from './dispatcher';
import type { NotificationInboxInsert, NotificationInboxStore } from './inbox-store';
import type {
  ClaimedNotificationOccurrence,
  NotificationOccurrenceStore,
} from './occurrence-store';

const now = new Date('2026-08-24T12:00:00Z');

function occurrence(
  overrides: Partial<ClaimedNotificationOccurrence> = {},
): ClaimedNotificationOccurrence {
  return {
    id: 'occurrence-1',
    userId: 'user-1',
    scheduleId: null,
    category: 'line',
    scheduleRevision: 1,
    dueAt: now,
    state: 'sending',
    dropReason: null,
    attempts: 1,
    leaseUntil: new Date(now.getTime() + 120_000),
    dedupeKey: 'dedupe-1',
    payload: { topicKind: 'line', topicId: 'IDFM:C01371', lineName: '1' },
    deliveryShard: 0,
    badge: 0,
    sentToday: 0,
    ...overrides,
  };
}

function dispatcherFor(options: {
  claims: ClaimedNotificationOccurrence[];
  sendToUser?: NotificationDelivery['sendToUser'];
  muted?: boolean;
  snapshot?: () => Promise<null>;
}) {
  const events: string[] = [];
  const finished: Array<{ ids: readonly string[]; state: string; reason?: string }> = [];
  const inboxRows: NotificationInboxInsert[] = [];
  const counters = { claimDue: 0 };
  let pending = [...options.claims];
  const occurrences: NotificationOccurrenceStore = {
    insert: async () => {},
    claimDue: async () => {
      counters.claimDue += 1;
      const batch = pending;
      pending = [];
      return batch;
    },
    reapExpired: async () => 0,
    finish: async (ids, state, reason) => {
      events.push(`finish:${state}${reason ? `:${reason}` : ''}`);
      finished.push({ ids, state, reason });
    },
  };
  const inbox: NotificationInboxStore = {
    insert: async (input) => {
      events.push(`inbox:${input.id}`);
      inboxRows.push(input);
      return input.id ?? 'inbox-item';
    },
    list: async () => ({ items: [], unreadCount: 0 }),
    markRead: async () => {},
    unreadCount: async () => 0,
  };
  const delivery: NotificationDelivery = {
    sendToDevice: async () => {},
    sendToUser: async (userId, notification) => {
      events.push(`apns:${userId}`);
      await options.sendToUser?.(userId, notification);
    },
  };
  const dispatcher = new NotificationDispatcher({
    occurrences,
    inbox,
    delivery,
    schedules: {
      schedule: async () => undefined,
      preferences: async () => null,
      muted: async () => options.muted ?? false,
    },
    snapshot: options.snapshot ?? (async () => null),
    now: () => now,
  });
  return { dispatcher, events, finished, inboxRows, counters };
}

test('the inbox row is durable before APNs delivery is attempted', async () => {
  const { dispatcher, events } = dispatcherFor({ claims: [occurrence()] });

  const handled = await dispatcher.pollOnce(0);

  expect(handled).toBe(1);
  expect(events).toEqual([
    'inbox:occurrence:occurrence-1',
    'apns:user-1',
    'finish:sent',
  ]);
});

test('a retryable APNs failure leaves the occurrence leased for the reaper after the inbox write', async () => {
  const { dispatcher, events, finished, inboxRows } = dispatcherFor({
    claims: [occurrence()],
    sendToUser: async () => {
      throw new NotificationDeliveryError(new Error('network'));
    },
  });

  await dispatcher.pollOnce(0);

  expect(inboxRows).toHaveLength(1);
  expect(events).toEqual(['inbox:occurrence:occurrence-1', 'apns:user-1']);
  expect(finished).toHaveLength(0);
});

test('a permanent APNs rejection drops the occurrence after the inbox write', async () => {
  const { dispatcher, events, finished } = dispatcherFor({
    claims: [occurrence()],
    sendToUser: async () => {
      throw new NotificationDeliveryError(new APNsError(400, 'BadCollapseId', null));
    },
  });

  await dispatcher.pollOnce(0);

  expect(events).toEqual([
    'inbox:occurrence:occurrence-1',
    'apns:user-1',
    'finish:dropped:stale',
  ]);
  expect(finished[0]?.ids).toEqual(['occurrence-1']);
});

test('a policy drop records the inbox row with its reason and never reaches APNs', async () => {
  const { dispatcher, events, inboxRows } = dispatcherFor({
    claims: [occurrence()],
    muted: true,
  });

  await dispatcher.pollOnce(0);

  expect(events).toEqual([
    'inbox:occurrence:occurrence-1',
    'finish:dropped:muted',
  ]);
  expect(inboxRows[0]?.dropReason).toBe('muted');
});

test('overlapping polls do not double-claim occurrences', async () => {
  let releaseSnapshot: () => void = () => {};
  const gate = new Promise<void>((resolve) => {
    releaseSnapshot = resolve;
  });
  const { dispatcher, counters } = dispatcherFor({
    claims: [occurrence()],
    snapshot: () => gate.then(() => null),
  });

  const first = dispatcher.pollOnce(0);
  const second = await dispatcher.pollOnce(0);
  releaseSnapshot();

  expect(second).toBe(0);
  expect(await first).toBe(1);
  expect(counters.claimDue).toBe(1);
});

test('delivery fans out in waves of at most fifty occurrences', async () => {
  const claims = Array.from({ length: 120 }, (_, index) =>
    occurrence({
      id: `occurrence-${index}`,
      userId: `user-${index}`,
      dedupeKey: `dedupe-${index}`,
    }),
  );
  let inFlight = 0;
  let maxInFlight = 0;
  let sent = 0;
  const { dispatcher } = dispatcherFor({
    claims,
    sendToUser: async () => {
      inFlight += 1;
      maxInFlight = Math.max(maxInFlight, inFlight);
      await new Promise((resolve) => setTimeout(resolve, 1));
      inFlight -= 1;
      sent += 1;
    },
  });

  const handled = await dispatcher.pollOnce(0);

  expect(handled).toBe(120);
  expect(sent).toBe(120);
  expect(maxInFlight).toBeLessThanOrEqual(50);
  expect(maxInFlight).toBeGreaterThan(1);
});

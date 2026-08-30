import { expect, test } from 'bun:test';

import type { MeetupPlanningService } from './planning';
import { noOpMeetupSemanticNotifier } from './notifier';
import {
  runMeetupMaintenanceCycle,
  type MeetupMaintenanceRepository,
} from './runtime';

test('scheduled meetup maintenance refreshes due plans and isolates failures', async () => {
  const refreshed: string[] = [];
  const stale: string[] = [];
  const planning: MeetupPlanningService = {
    async recompute({ meetupId }) {
      if (meetupId === 'failed') throw new Error('planner unavailable');
      refreshed.push(meetupId);
    },
  };
  const repository: MeetupMaintenanceRepository = {
    async due() {
      return [
        { id: 'j-minus-one', targetArrivalAt: new Date('2026-08-30T12:00:00Z') },
        { id: 'failed', targetArrivalAt: new Date('2026-08-29T14:00:00Z') },
        { id: 'h-minus-two', targetArrivalAt: new Date('2026-08-29T14:00:00Z') },
      ];
    },
    async markStale(meetupId) { stale.push(meetupId); },
    async expireInvitations() { return 2; },
    async expireMeetups() { return 1; },
    async purge() { return 1; },
  };

  const result = await runMeetupMaintenanceCycle({
    planning,
    now: new Date('2026-08-29T12:00:00Z'),
    redisClient: { async set() { return 'OK'; } },
    repository,
  });

  expect(refreshed).toEqual(['j-minus-one', 'h-minus-two']);
  expect(stale).toEqual(['failed']);
  expect(result).toEqual({
    refreshed: 2,
    failed: 1,
    expired: 2,
    meetupsExpired: 1,
    purged: 1,
  });
});

test('only one replica owns a maintenance cycle', async () => {
  let queried = false;
  const repository: MeetupMaintenanceRepository = {
    async due() { queried = true; return []; },
    async markStale() {},
    async expireInvitations() { return 0; },
    async expireMeetups() { return 0; },
    async purge() { return 0; },
  };

  const result = await runMeetupMaintenanceCycle({
    planning: { async recompute() {} },
    redisClient: { async set() { return null; } },
    repository,
  });

  expect(queried).toBe(false);
  expect(result).toEqual({
    refreshed: 0,
    failed: 0,
    expired: 0,
    meetupsExpired: 0,
    purged: 0,
  });
});

test('the H-2 refresh emits one semantic departure reminder', async () => {
  const notified: string[] = [];
  const result = await runMeetupMaintenanceCycle({
    planning: { async recompute() {} },
    now: new Date('2026-08-29T12:00:00Z'),
    redisClient: { async set() { return 'OK'; } },
    repository: {
      async due() {
        return [{ id: 'h-minus-two', targetArrivalAt: new Date('2026-08-29T14:00:00Z') }];
      },
      async markStale() {},
      async expireInvitations() { return 0; },
      async expireMeetups() { return 0; },
      async purge() { return 0; },
    },
    notifier: {
      ...noOpMeetupSemanticNotifier,
      async departureSoon(meetupId) { notified.push(meetupId); },
    },
  });

  expect(result.refreshed).toBe(1);
  expect(notified).toEqual(['h-minus-two']);
});

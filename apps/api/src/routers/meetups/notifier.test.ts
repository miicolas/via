import { expect, test } from 'bun:test';

import type { DeviceNotification, NotificationDelivery } from '../../notifications';
import { createMeetupSemanticNotifier } from './notifier';

test('semantic rendez-vous pushes contain a route but no location payload', async () => {
  const sent: Array<{ userId: string; notification: DeviceNotification }> = [];
  const delivery: NotificationDelivery = {
    async sendToDevice() {},
    async sendToUser(userId, notification) { sent.push({ userId, notification }); },
  };
  const notifier = createMeetupSemanticNotifier(delivery);

  await notifier.planChanged({
    meetupId: '46f9d69c-c8b3-499d-86c1-68b314a7159b',
    destinationName: 'Châtelet',
    targetArrivalAt: new Date('2026-08-30T19:00:00+02:00'),
    userIds: ['alice', 'bob', 'alice'],
  });

  expect(sent.map(({ userId }) => userId)).toEqual(['alice', 'bob']);
  expect(sent[0]?.notification.data).toEqual({
    url: 'via://meetup/46f9d69c-c8b3-499d-86c1-68b314a7159b',
    meetupEvent: 'plan',
  });
  const wire = JSON.stringify(sent);
  expect(wire).not.toContain('latitude');
  expect(wire).not.toContain('longitude');
  expect(wire).not.toContain('ciphertext');
});

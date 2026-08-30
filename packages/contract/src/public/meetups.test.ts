import { expect, test } from 'bun:test';

import {
  publicFriendInvitationResponseSchema,
  publicMeetupInvitationResponseSchema,
} from './meetups';

test('public rendez-vous preview rejects participant and live data', () => {
  const safe = {
    organizerDisplayName: 'Alice',
    destination: { id: 'C', name: 'Châtelet' },
    targetArrivalAt: '2026-08-30T19:00:00+02:00',
    status: 'available',
    expiresAt: '2026-08-30T21:00:00+02:00',
  };
  expect(publicMeetupInvitationResponseSchema.safeParse(safe).success).toBe(true);
  expect(publicMeetupInvitationResponseSchema.safeParse({
    ...safe,
    participants: ['Bob'],
    ciphertext: 'secret',
  }).success).toBe(false);
});

test('public friend preview contains only the inviter and link state', () => {
  expect(publicFriendInvitationResponseSchema.parse({
    inviterDisplayName: 'Sam',
    status: 'available',
    expiresAt: '2026-09-05T12:00:00+02:00',
  })).toEqual({
    inviterDisplayName: 'Sam',
    status: 'available',
    expiresAt: '2026-09-05T12:00:00+02:00',
  });
});

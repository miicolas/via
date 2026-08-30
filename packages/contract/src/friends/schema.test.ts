import { expect, test } from 'bun:test';

import {
  friendInvitationCreateInputSchema,
  friendInvitationTokenSchema,
  friendshipSchema,
} from './schema';

test('friend invitations are opaque, idempotent links', () => {
  const input = friendInvitationCreateInputSchema.parse({
    idempotencyKey: 'd913aa4b-a09b-4d58-ad72-cff3cb28cb2f',
  });

  expect(input.idempotencyKey).toBe('d913aa4b-a09b-4d58-ad72-cff3cb28cb2f');
  expect(friendInvitationTokenSchema.safeParse('a'.repeat(43)).success).toBe(true);
  expect(friendInvitationTokenSchema.safeParse('public name').success).toBe(false);
});

test('a friendship exposes initials rather than a private avatar', () => {
  const friendship = friendshipSchema.parse({
    userId: 'friend-user-id',
    displayName: 'Sam Lee',
    initials: 'SL',
    friendsSince: '2026-08-29T12:00:00+02:00',
  });

  expect(friendship.initials).toBe('SL');
  expect(JSON.stringify(friendship)).not.toContain('image');
});

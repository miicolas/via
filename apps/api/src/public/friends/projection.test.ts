import { expect, test } from 'bun:test';

import { toPublicFriendInvitation } from './projection';

test('public friend invitation projection reconstructs an allowlist', () => {
  const preview = {
    inviterDisplayName: 'Alice',
    inviterUserId: 'private-user-id',
    status: 'available',
    expiresAt: '2026-08-30T21:00:00+02:00',
  } as const;

  const projected = toPublicFriendInvitation(preview);

  expect(projected).toEqual({
    inviterDisplayName: 'Alice',
    status: 'available',
    expiresAt: '2026-08-30T21:00:00+02:00',
  });
  expect(JSON.stringify(projected)).not.toContain('private-user-id');
});

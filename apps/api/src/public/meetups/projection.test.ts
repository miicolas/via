import { expect, test } from 'bun:test';

import { toPublicMeetupInvitation } from './projection';

test('public rendez-vous projection reconstructs an allowlist', () => {
  const projected = toPublicMeetupInvitation({
    organizerDisplayName: 'Alice',
    destination: {
      id: 'C',
      name: 'Châtelet',
      coordinate: { latitude: 48.85, longitude: 2.35 },
    },
    targetArrivalAt: '2026-08-30T19:00:00+02:00',
    status: 'available',
    expiresAt: '2026-08-30T21:00:00+02:00',
  });

  expect(projected).toEqual({
    organizerDisplayName: 'Alice',
    destination: { id: 'C', name: 'Châtelet' },
    targetArrivalAt: '2026-08-30T19:00:00+02:00',
    status: 'available',
    expiresAt: '2026-08-30T21:00:00+02:00',
  });
  expect(JSON.stringify(projected)).not.toContain('latitude');
});

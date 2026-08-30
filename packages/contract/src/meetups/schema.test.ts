import { describe, expect, test } from 'bun:test';

import {
  meetupCreateInputSchema,
  meetupLivePublishInputSchema,
  meetupListResponseSchema,
  meetupResponseSchema,
  meetupTokenSchema,
} from './schema';

const station = {
  id: 'stop-area:C',
  name: 'Châtelet – Les Halles',
  coordinate: { latitude: 48.861, longitude: 2.347 },
};

const origin = {
  kind: 'address' as const,
  id: 'address:alice',
  name: 'Rue de Lyon',
  context: 'Paris 12e',
  coordinate: { latitude: 48.846, longitude: 2.372 },
};

describe('meetup contract', () => {
  test('accepts the complete one-off rendez-vous intent', () => {
    const parsed = meetupCreateInputSchema.parse({
      destination: station,
      targetArrivalAt: '2026-08-30T19:00:00+02:00',
      organizerDisplayName: 'Alice',
      origin,
      shareLevel: 'positionAndProgress',
      publicKey: 'x25519-public-key',
      idempotencyKey: 'd913aa4b-a09b-4d58-ad72-cff3cb28cb2f',
    });

    expect(parsed.destination.id).toBe('stop-area:C');
    expect(parsed.origin.kind).toBe('address');
    expect(parsed.shareLevel).toBe('positionAndProgress');
  });

  test('requires a URL-safe 256-bit invitation token', () => {
    expect(meetupTokenSchema.safeParse('short').success).toBe(false);
    expect(meetupTokenSchema.safeParse('a'.repeat(43)).success).toBe(true);
  });

  test('direct account invitations carry a scoped capability to their recipient', () => {
    const parsed = meetupListResponseSchema.parse({
      meetups: [],
      pendingInvitations: [{
        invitation: {
          id: '5e2c6956-2504-4fd3-9cb6-3ad715b8a921',
          status: 'pending',
          invitedUserId: 'friend-user',
          expiresAt: '2026-08-30T21:00:00+02:00',
          createdAt: '2026-08-29T12:00:00+02:00',
        },
        token: 'a'.repeat(43),
        meetupId: '46f9d69c-c8b3-499d-86c1-68b314a7159b',
        organizerDisplayName: 'Alice',
        destination: station,
        targetArrivalAt: '2026-08-30T19:00:00+02:00',
      }],
    });

    expect(parsed.pendingInvitations[0]?.token).toHaveLength(43);
  });

  test('live presence is opaque to the server', () => {
    const parsed = meetupLivePublishInputSchema.parse({
      meetupId: '46f9d69c-c8b3-499d-86c1-68b314a7159b',
      progress: {
        status: 'underway',
        serviceId: 'service:rer-a:123',
        station: station,
        updatedAt: '2026-08-30T18:25:00+02:00',
      },
      presence: {
        keyRevision: 2,
        ciphertext: 'base64url-ciphertext',
        sentAt: '2026-08-30T18:25:00+02:00',
      },
    });

    expect(parsed.presence).toEqual({
      keyRevision: 2,
      ciphertext: 'base64url-ciphertext',
      sentAt: '2026-08-30T18:25:00+02:00',
    });
    expect(JSON.stringify(parsed.presence)).not.toContain('latitude');
    expect(JSON.stringify(parsed.presence)).not.toContain('accuracy');
  });

  test('bounds a rendez-vous response to four participants', () => {
    const participant = (index: number) => ({
      id: `2b0ba7a1-671f-40ee-9374-bc2f8d59ffb${index}`,
      displayName: `Participant ${index}`,
      role: index === 0 ? ('organizer' as const) : ('member' as const),
      state: 'ready' as const,
      shareLevel: 'progressOnly' as const,
      zone: 'middle' as const,
      createdAt: '2026-08-29T12:00:00+02:00',
      updatedAt: '2026-08-29T12:00:00+02:00',
    });

    const base = {
      id: '46f9d69c-c8b3-499d-86c1-68b314a7159b',
      destination: station,
      targetArrivalAt: '2026-08-30T19:00:00+02:00',
      phase: 'ready' as const,
      revision: 3,
      keyRevision: 1,
      currentParticipantId: '2b0ba7a1-671f-40ee-9374-bc2f8d59ffb0',
      isOrganizer: true,
      createdAt: '2026-08-29T12:00:00+02:00',
      updatedAt: '2026-08-29T12:00:00+02:00',
    };

    expect(
      meetupResponseSchema.safeParse({ ...base, participants: [0, 1, 2, 3].map(participant) })
        .success,
    ).toBe(true);
    expect(
      meetupResponseSchema.safeParse({ ...base, participants: [0, 1, 2, 3, 4].map(participant) })
        .success,
    ).toBe(false);
  });
});

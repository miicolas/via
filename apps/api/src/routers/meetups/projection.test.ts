import { expect, test } from 'bun:test';

import type { Journey, MeetupPlan } from '@via/contract';
import type {
  MeetupInvitationRow,
  MeetupParticipantRow,
  MeetupRow,
} from '@via/db/schema';

import { createMeetupOriginCipher } from './origin-crypto';
import { projectMeetup } from './projection';

const now = new Date('2026-08-29T12:00:00+02:00');
const originCipher = createMeetupOriginCipher([
  { version: 1, key: Buffer.alloc(32, 8) },
]);
const journey = (id: string): Journey => ({
  id,
  qualifier: 'recommended',
  durationSeconds: 600,
  walkingDurationSeconds: 0,
  transferCount: 0,
  departureAt: '2026-08-30T18:40:00+02:00',
  arrivalAt: '2026-08-30T18:50:00+02:00',
  status: 'normal',
  warnings: [],
  sections: [{
    id: `${id}-private-section`,
    type: 'transit',
    durationSeconds: 600,
    from: { name: 'Origine privée', coordinate: { latitude: 48.8, longitude: 2.3 } },
    to: { name: 'C', coordinate: { latitude: 48.85, longitude: 2.35 } },
    departureAt: '2026-08-30T18:40:00+02:00',
    arrivalAt: '2026-08-30T18:50:00+02:00',
    geometry: [],
    stops: [],
  }],
});

const meetup = {
  id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  organizerUserId: 'organizer-user',
  destinationId: 'C',
  destinationName: 'Châtelet',
  destinationLatitude: 48.85,
  destinationLongitude: 2.35,
  targetArrivalAt: new Date('2026-08-30T19:00:00+02:00'),
  phase: 'ready',
  revision: 2,
  keyRevision: 1,
  plan: null,
  nextRefreshAt: null,
  createdAt: now,
  updatedAt: now,
  purgeAt: new Date('2026-09-06T19:00:00+02:00'),
} satisfies MeetupRow;

const participant = (
  id: string,
  role: 'organizer' | 'member',
  ownedJourney: Journey,
): MeetupParticipantRow => ({
  id,
  meetupId: meetup.id,
  userId: role === 'organizer' ? 'organizer-user' : 'member-user',
  tokenHash: `${id}-hash`,
  idempotencyKey: `${id}-idempotency`,
  displayName: role === 'organizer' ? 'Alice' : 'Bob',
  role,
  state: 'ready',
  shareLevel: 'progressOnly',
  zone: 'middle',
  encryptedOrigin: { keyVersion: 1, nonce: 'n', ciphertext: 'c', authenticationTag: 't' },
  planningPolicy: {},
  journey: originCipher.encryptJourney(ownedJourney),
  firstBoardingStation: null,
  departureAt: new Date(ownedJourney.departureAt),
  arrivalAt: new Date(ownedJourney.arrivalAt),
  publicKey: 'public-key-at-least-16',
  createdAt: now,
  updatedAt: now,
});

test('a participant receives only their own complete journey', () => {
  const organizer = participant('11111111-1111-4111-8111-111111111111', 'organizer', journey('alice-private'));
  const member = participant('22222222-2222-4222-8222-222222222222', 'member', journey('bob-private'));
  const plan: MeetupPlan = {
    revision: 2,
    status: 'fallbackAtDestination',
    generatedAt: now.toISOString(),
    isStale: false,
    participantJourneys: [
      { participantId: organizer.id, departureAt: journey('alice-private').departureAt, arrivalAt: journey('alice-private').arrivalAt },
      { participantId: member.id, departureAt: journey('bob-private').departureAt, arrivalAt: journey('bob-private').arrivalAt },
    ],
    joinPoints: [],
  };
  const invitation = {
    id: '33333333-3333-4333-8333-333333333333',
    meetupId: meetup.id,
    tokenHash: 'secret-invitation-hash',
    idempotencyKey: 'invite-idempotency',
    invitedUserId: null,
    status: 'pending',
    claimedByParticipantId: null,
    createdAt: now,
    expiresAt: new Date('2026-08-30T21:00:00+02:00'),
    respondedAt: null,
    revokedAt: null,
  } satisfies MeetupInvitationRow;

  const projected = projectMeetup({
    meetup: { ...meetup, plan: plan as unknown as Record<string, unknown> },
    participants: [organizer, member],
    invitations: [invitation],
    currentParticipant: member,
    originCipher,
  });

  expect(projected.plan?.participantJourneys[0]?.journey).toBeUndefined();
  expect(projected.plan?.participantJourneys[1]?.journey?.id).toBe('bob-private');
  expect(projected.invitations).toBeUndefined();
  expect(JSON.stringify(projected)).not.toContain('alice-private-section');
  expect(JSON.stringify(projected)).not.toContain('secret-invitation-hash');
  expect(JSON.stringify(meetup.plan)).not.toContain('private-section');
  expect(JSON.stringify(member.journey)).not.toContain('bob-private-section');
});

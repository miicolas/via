import { describe, expect, test } from 'bun:test';

import { MEETUP_GRACE_MS } from '@via/contract';
import type {
  MeetupInvitationRow,
  MeetupParticipantRow,
  MeetupRow,
} from '@via/db/schema';

import {
  ensureOpen,
  isActiveParticipant,
  rendezVous,
} from './aggregate';
import { MeetupServiceError } from './errors';

const now = new Date('2026-08-30T18:00:00+02:00');
const targetArrivalAt = new Date('2026-08-30T19:00:00+02:00');
const graceEnd = new Date(targetArrivalAt.getTime() + MEETUP_GRACE_MS);

const meetup = (overrides: Partial<MeetupRow> = {}): MeetupRow => ({
  id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  organizerUserId: 'organizer-user',
  destinationId: 'C',
  destinationName: 'Châtelet',
  destinationLatitude: 48.85,
  destinationLongitude: 2.35,
  targetArrivalAt,
  phase: 'ready',
  revision: 2,
  keyRevision: 1,
  plan: null,
  nextRefreshAt: null,
  createdAt: now,
  updatedAt: now,
  purgeAt: new Date('2026-09-06T19:00:00+02:00'),
  ...overrides,
});

const participant = (
  id: string,
  state: MeetupParticipantRow['state'],
): MeetupParticipantRow => ({
  id,
  meetupId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  userId: `user-${id}`,
  tokenHash: `${id}-hash`,
  idempotencyKey: `${id}-idempotency`,
  displayName: id,
  role: id === 'organizer' ? 'organizer' : 'member',
  state,
  shareLevel: 'progressOnly',
  zone: 'middle',
  encryptedOrigin: { keyVersion: 1, nonce: 'n', ciphertext: 'c', authenticationTag: 't' },
  planningPolicy: {},
  journey: null,
  firstBoardingStation: null,
  departureAt: null,
  arrivalAt: null,
  publicKey: 'public-key-at-least-16',
  createdAt: now,
  updatedAt: now,
});

const invitation = (
  id: string,
  overrides: Partial<MeetupInvitationRow> = {},
): MeetupInvitationRow => ({
  id,
  meetupId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  tokenHash: `${id}-hash`,
  idempotencyKey: `${id}-idempotency`,
  invitedUserId: null,
  status: 'pending',
  claimedByParticipantId: null,
  createdAt: now,
  expiresAt: graceEnd,
  respondedAt: null,
  revokedAt: null,
  ...overrides,
});

describe('rendezVous seats', () => {
  test('a pending Invitation reserves a seat alongside active Participants', () => {
    const aggregate = rendezVous({
      meetup: meetup(),
      participants: [participant('organizer', 'ready')],
      invitations: [invitation('inv-1'), invitation('inv-2')],
    });
    expect(aggregate.seatsRemaining(now)).toBe(1);
  });

  test('expired, revoked and answered Invitations free their seat', () => {
    const aggregate = rendezVous({
      meetup: meetup(),
      participants: [participant('organizer', 'ready')],
      invitations: [
        invitation('inv-expired', { expiresAt: now }),
        invitation('inv-revoked', { status: 'revoked', revokedAt: now }),
        invitation('inv-declined', { status: 'declined', respondedAt: now }),
      ],
    });
    expect(aggregate.pendingInvitations(now)).toEqual([]);
    expect(aggregate.seatsRemaining(now)).toBe(3);
  });

  test('Participants who left, were removed or declined do not hold a seat', () => {
    const aggregate = rendezVous({
      meetup: meetup(),
      participants: [
        participant('organizer', 'ready'),
        participant('gone', 'left'),
        participant('kicked', 'removed'),
        participant('refused', 'declined'),
      ],
      invitations: [],
    });
    expect(aggregate.activeParticipants().map(({ id }) => id)).toEqual(['organizer']);
    expect(aggregate.seatsRemaining(now)).toBe(3);
  });

  test('every active state counts as taking part', () => {
    for (const state of ['configuring', 'ready', 'underway', 'joined', 'arrived'] as const) {
      expect(isActiveParticipant(state)).toBe(true);
    }
    for (const state of ['declined', 'left', 'removed'] as const) {
      expect(isActiveParticipant(state)).toBe(false);
    }
  });
});

describe('rendezVous invitationHasSeat', () => {
  test('a fully invited Rendez-vous is full for the organizer but keeps every held seat', () => {
    // 1 Participant + 3 pending Invitations: the organizer is told "full" at
    // invite time, yet each link-holder previews "available" because the seat
    // their Invitation reserved is theirs to claim. Both answers come from the
    // same counting rule.
    const aggregate = rendezVous({
      meetup: meetup(),
      participants: [participant('organizer', 'ready')],
      invitations: [invitation('inv-1'), invitation('inv-2'), invitation('inv-3')],
    });
    expect(aggregate.seatsRemaining(now)).toBe(0);
    for (const id of ['inv-1', 'inv-2', 'inv-3']) {
      expect(aggregate.invitationHasSeat(id, now)).toBe(true);
    }
  });

  test('a Rendez-vous with four active Participants is full for everyone', () => {
    // The previously inconsistent case: invite-time said "full" while the
    // link preview said "available". Both now refuse.
    const aggregate = rendezVous({
      meetup: meetup(),
      participants: [
        participant('organizer', 'ready'),
        participant('bob', 'configuring'),
        participant('chloe', 'underway'),
        participant('dan', 'arrived'),
      ],
      invitations: [invitation('inv-stray')],
    });
    expect(aggregate.seatsRemaining(now)).toBeLessThanOrEqual(0);
    expect(aggregate.invitationHasSeat('inv-stray', now)).toBe(false);
  });

  test('oversubscribed reservations refuse every claim past the limit', () => {
    // 3 Participants + 2 pending Invitations can only happen when expired
    // Invitations were revived by a target change; neither holder is promised
    // the single seat left.
    const aggregate = rendezVous({
      meetup: meetup(),
      participants: [
        participant('organizer', 'ready'),
        participant('bob', 'ready'),
        participant('chloe', 'ready'),
      ],
      invitations: [invitation('inv-1'), invitation('inv-2')],
    });
    expect(aggregate.invitationHasSeat('inv-1', now)).toBe(false);
    expect(aggregate.invitationHasSeat('inv-2', now)).toBe(false);
  });
});

describe('rendezVous openness', () => {
  test('the grace window closes exactly two hours after the target arrival', () => {
    const aggregate = rendezVous({
      meetup: meetup(),
      participants: [participant('organizer', 'ready')],
      invitations: [],
    });
    expect(aggregate.withinGraceWindow(new Date(graceEnd.getTime() - 1))).toBe(true);
    expect(aggregate.withinGraceWindow(graceEnd)).toBe(false);
    expect(aggregate.isOpen(new Date(graceEnd.getTime() - 1))).toBe(true);
    expect(aggregate.isOpen(graceEnd)).toBe(false);
  });

  test('a terminal phase closes the Rendez-vous regardless of the clock', () => {
    for (const phase of ['cancelled', 'completed', 'expired'] as const) {
      const aggregate = rendezVous({
        meetup: meetup({ phase }),
        participants: [],
        invitations: [],
      });
      expect(aggregate.isMutable()).toBe(false);
      expect(aggregate.isOpen(now)).toBe(false);
    }
    expect(rendezVous({
      meetup: meetup({ phase: 'live' }),
      participants: [],
      invitations: [],
    }).isMutable()).toBe(true);
  });

  test('ensureOpen distinguishes a terminal phase from an elapsed grace window', () => {
    const cancelled = rendezVous({
      meetup: meetup({ phase: 'cancelled' }),
      participants: [],
      invitations: [],
    });
    expect(() => ensureOpen(cancelled, now))
      .toThrow(new MeetupServiceError('conflict'));

    const past = rendezVous({ meetup: meetup(), participants: [], invitations: [] });
    expect(() => ensureOpen(past, graceEnd))
      .toThrow(new MeetupServiceError('expired'));
    expect(() => ensureOpen(past, now)).not.toThrow();
  });
});

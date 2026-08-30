import {
  MEETUP_GRACE_MS,
  MEETUP_PARTICIPANT_LIMIT,
  type MeetupStation,
} from '@via/contract';
import type {
  MeetupInvitationRow,
  MeetupParticipantRow,
  MeetupRow,
} from '@via/db';

import { MeetupServiceError } from './errors';

/**
 * The states that still count as taking part. Membership drives the seat
 * count, the notification audience and the key-envelope recipients, so it is
 * named once here rather than re-listed by each of those readers. Spread it
 * into `inArray` for SQL; use {@link isActiveParticipant} for loaded rows.
 */
export const ACTIVE_PARTICIPANT_STATES = [
  'configuring',
  'ready',
  'underway',
  'joined',
  'arrived',
] as const;

export function isActiveParticipant(state: string): boolean {
  return (ACTIVE_PARTICIPANT_STATES as readonly string[]).includes(state);
}

const TERMINAL_PHASES = ['cancelled', 'completed', 'expired'] as const;

export type RendezVousRows = {
  meetup: MeetupRow;
  participants: MeetupParticipantRow[];
  invitations: MeetupInvitationRow[];
};

export type RendezVous = RendezVousRows & {
  activeParticipants(): MeetupParticipantRow[];
  pendingInvitations(now: Date): MeetupInvitationRow[];
  /**
   * Seats left to promise. A pending unexpired Invitation reserves a seat the
   * moment it is created (ADR-0006 makes the link a capability: the promise it
   * carries must survive until it expires), so both occupied seats and
   * outstanding reservations count against {@link MEETUP_PARTICIPANT_LIMIT}.
   */
  seatsRemaining(now: Date): number;
  /**
   * Whether this Invitation can still be exchanged for a seat. Its own
   * reservation counts as its seat, so a fully invited Rendez-vous stays
   * available to everyone already holding a link while refusing new ones.
   */
  invitationHasSeat(invitationId: string, now: Date): boolean;
  /** False once the phase is terminal (cancelled, completed, expired). */
  isMutable(): boolean;
  /** ADR-0006: the Rendez-vous stays live until two hours past the target. */
  withinGraceWindow(now: Date): boolean;
  /** Mutability and the grace window together: can anything still happen? */
  isOpen(now: Date): boolean;
};

/** The loaded-once Rendez-vous aggregate: pure rules over already-read rows. */
export function rendezVous(rows: RendezVousRows): RendezVous {
  const { meetup, participants, invitations } = rows;

  const activeParticipants = () =>
    participants.filter((participant) => isActiveParticipant(participant.state));
  const pendingInvitations = (now: Date) =>
    invitations.filter(
      (invitation) => invitation.status === 'pending' && invitation.expiresAt > now,
    );
  const seatsRemaining = (now: Date) =>
    MEETUP_PARTICIPANT_LIMIT - activeParticipants().length - pendingInvitations(now).length;
  const invitationHasSeat = (invitationId: string, now: Date) => {
    const reserved = pendingInvitations(now)
      .some((invitation) => invitation.id === invitationId);
    return seatsRemaining(now) + (reserved ? 1 : 0) > 0;
  };
  const isMutable = () =>
    !(TERMINAL_PHASES as readonly string[]).includes(meetup.phase);
  const withinGraceWindow = (now: Date) =>
    meetup.targetArrivalAt.getTime() + MEETUP_GRACE_MS > now.getTime();

  return {
    ...rows,
    activeParticipants,
    pendingInvitations,
    seatsRemaining,
    invitationHasSeat,
    isMutable,
    withinGraceWindow,
    isOpen: (now: Date) => isMutable() && withinGraceWindow(now),
  };
}

export function ensureMutable(rendezVous: Pick<RendezVous, 'isMutable'>): void {
  if (!rendezVous.isMutable()) throw new MeetupServiceError('conflict');
}

export function ensureOpen(
  rendezVous: Pick<RendezVous, 'isMutable' | 'withinGraceWindow'>,
  now: Date,
): void {
  ensureMutable(rendezVous);
  if (!rendezVous.withinGraceWindow(now)) throw new MeetupServiceError('expired');
}

export function meetupDestination(meetup: Pick<
  MeetupRow,
  'destinationId' | 'destinationName' | 'destinationLatitude' | 'destinationLongitude'
>): MeetupStation {
  return {
    id: meetup.destinationId,
    name: meetup.destinationName,
    coordinate: {
      latitude: meetup.destinationLatitude,
      longitude: meetup.destinationLongitude,
    },
  };
}

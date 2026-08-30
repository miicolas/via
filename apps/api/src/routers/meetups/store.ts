import { and, eq, inArray, or } from 'drizzle-orm';
import {
  db,
  meetupInvitations,
  meetupParticipants,
  meetups,
  type MeetupParticipantRow,
  type MeetupRow,
} from '@via/db';

import type { ApiContext } from '../../orpc/implementer';
import { rendezVous, type RendezVous, type RendezVousRows } from './aggregate';
import { capabilityTokenHash } from './capability';
import { MeetupServiceError } from './errors';

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];

export async function loadMeetupAggregate(meetupId: string): Promise<RendezVous> {
  const [meetupRows, participants, invitations] = await Promise.all([
    db.select().from(meetups).where(eq(meetups.id, meetupId)).limit(1),
    db.select().from(meetupParticipants).where(eq(meetupParticipants.meetupId, meetupId)),
    db.select().from(meetupInvitations).where(eq(meetupInvitations.meetupId, meetupId)),
  ]);
  const meetup = meetupRows[0];
  if (!meetup) throw new MeetupServiceError('not_found');
  return rendezVous({ meetup, participants, invitations });
}

/**
 * The list view's read. One query per table for the whole page instead of
 * {@link loadMeetupAggregate} per row, which is three round trips each.
 */
export async function loadMeetupAggregates(
  meetupIds: string[],
): Promise<Map<string, RendezVous>> {
  const aggregates = new Map<string, RendezVous>();
  if (meetupIds.length === 0) return aggregates;

  const [meetupRows, participants, invitations] = await Promise.all([
    db.select().from(meetups).where(inArray(meetups.id, meetupIds)),
    db.select().from(meetupParticipants).where(inArray(meetupParticipants.meetupId, meetupIds)),
    db.select().from(meetupInvitations).where(inArray(meetupInvitations.meetupId, meetupIds)),
  ]);

  const rows = new Map<string, RendezVousRows>();
  for (const meetup of meetupRows) {
    rows.set(meetup.id, { meetup, participants: [], invitations: [] });
  }
  for (const participant of participants) {
    rows.get(participant.meetupId)?.participants.push(participant);
  }
  for (const invitation of invitations) {
    rows.get(invitation.meetupId)?.invitations.push(invitation);
  }
  for (const [meetupId, aggregateRows] of rows) {
    aggregates.set(meetupId, rendezVous(aggregateRows));
  }
  return aggregates;
}

/**
 * The one place a Rendez-vous row is locked. Every writer that must hold the
 * seat count or the key revision still while it decides goes through here.
 * Returns the row read under the lock, or undefined when it never existed.
 */
export async function lockMeetup(
  tx: Tx,
  meetupId: string,
): Promise<MeetupRow | undefined> {
  const rows = await tx.select().from(meetups)
    .where(eq(meetups.id, meetupId))
    .limit(1)
    .for('update');
  return rows[0];
}

/**
 * The aggregate rebuilt under the row lock, so seat decisions read the same
 * rows the transaction is about to write. Sequential reads on purpose: the
 * transaction owns a single connection.
 */
export async function lockRendezVous(
  tx: Tx,
  meetupId: string,
): Promise<RendezVous | undefined> {
  const meetup = await lockMeetup(tx, meetupId);
  if (!meetup) return undefined;
  const participants = await tx.select().from(meetupParticipants)
    .where(eq(meetupParticipants.meetupId, meetupId));
  const invitations = await tx.select().from(meetupInvitations)
    .where(eq(meetupInvitations.meetupId, meetupId));
  return rendezVous({ meetup, participants, invitations });
}

/**
 * Just the revision column. The poll loop asks "did anything change?" every
 * few seconds per viewer, and the answer is usually no — loading the whole
 * aggregate to find that out is three round trips wasted on each miss.
 */
export async function meetupRevision(meetupId: string): Promise<number> {
  const rows = await db
    .select({ revision: meetups.revision })
    .from(meetups)
    .where(eq(meetups.id, meetupId))
    .limit(1);
  const revision = rows[0]?.revision;
  if (revision === undefined) throw new MeetupServiceError('not_found');
  return revision;
}

/** Organizer names for meetups the caller is not a participant of. */
export async function organizerDisplayNames(
  meetupIds: string[],
): Promise<Map<string, string>> {
  const names = new Map<string, string>();
  if (meetupIds.length === 0) return names;

  const rows = await db
    .select({
      meetupId: meetupParticipants.meetupId,
      displayName: meetupParticipants.displayName,
    })
    .from(meetupParticipants)
    .where(and(
      inArray(meetupParticipants.meetupId, meetupIds),
      eq(meetupParticipants.role, 'organizer'),
    ));
  for (const row of rows) names.set(row.meetupId, row.displayName);
  return names;
}

export async function authorizedParticipant(
  meetupId: string,
  context: Pick<ApiContext, 'userId' | 'meetupParticipantToken'>,
): Promise<MeetupParticipantRow> {
  const access = [];
  if (context.meetupParticipantToken) {
    access.push(eq(
      meetupParticipants.tokenHash,
      capabilityTokenHash(context.meetupParticipantToken),
    ));
  }
  if (context.userId) access.push(eq(meetupParticipants.userId, context.userId));
  if (access.length === 0) throw new MeetupServiceError('unauthorized');

  const rows = await db
    .select()
    .from(meetupParticipants)
    .where(and(
      eq(meetupParticipants.meetupId, meetupId),
      access.length === 1 ? access[0] : or(...access),
    ))
    .limit(1);
  const participant = rows[0];
  if (!participant || participant.state === 'left' || participant.state === 'removed') {
    throw new MeetupServiceError('unauthorized');
  }
  return participant;
}

export function requireOrganizer(participant: MeetupParticipantRow) {
  if (participant.role !== 'organizer') throw new MeetupServiceError('forbidden');
}

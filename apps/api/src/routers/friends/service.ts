import { randomUUID } from 'node:crypto';

import { alias } from 'drizzle-orm/pg-core';
import { and, eq, gt, or } from 'drizzle-orm';
import {
  db,
  friendInvitations,
  friendships,
  users,
  type FriendInvitationRow,
} from '@via/db';
import type {
  FriendInvitation,
  Friendship,
} from '@via/contract';

import { env, siteURL } from '../../env';
import { capabilityToken, capabilityTokenHash } from '../meetups/capability';
import { canonicalFriendPair, friendInitials } from './domain';

const FRIEND_INVITATION_TTL_MS = 7 * 24 * 60 * 60 * 1_000;

export type FriendServiceErrorReason =
  | 'not_found'
  | 'expired'
  | 'revoked'
  | 'self'
  | 'already_claimed';

export class FriendServiceError extends Error {
  constructor(readonly reason: FriendServiceErrorReason) {
    super(`Friend operation failed: ${reason}`);
    this.name = 'FriendServiceError';
  }
}

export async function createFriendInvitation({
  userId,
  idempotencyKey,
  now = new Date(),
}: {
  userId: string;
  idempotencyKey: string;
  now?: Date;
}) {
  const inviter = await userById(userId);
  if (!inviter) throw new FriendServiceError('not_found');
  const token = capabilityToken('friend-invitation', idempotencyKey, env.BETTER_AUTH_SECRET);
  const expiresAt = new Date(now.getTime() + FRIEND_INVITATION_TTL_MS);
  const rows = await db
    .insert(friendInvitations)
    .values({
      id: randomUUID(),
      tokenHash: capabilityTokenHash(token),
      idempotencyKey,
      inviterUserId: userId,
      status: 'pending',
      createdAt: now,
      expiresAt,
    })
    .onConflictDoUpdate({
      target: friendInvitations.idempotencyKey,
      set: { idempotencyKey },
    })
    .returning();
  const row = rows[0];
  if (!row) throw new FriendServiceError('not_found');

  return {
    invitation: friendInvitation(row, inviter.name),
    token,
    url: siteURL(`meet/friend/${token}`),
  };
}

export async function previewFriendInvitation(token: string, now = new Date()) {
  const row = await invitationWithInviter(token);
  if (!row) throw new FriendServiceError('not_found');
  return {
    inviterDisplayName: displayName(row.inviterName),
    status: invitationPublicStatus(row, now),
    expiresAt: row.expiresAt.toISOString(),
  } as const;
}

export async function acceptFriendInvitation({
  token,
  userId,
  now = new Date(),
}: {
  token: string;
  userId: string;
  now?: Date;
}): Promise<{ friendship: Friendship }> {
  const existing = await invitationWithInviter(token);
  if (!existing) throw new FriendServiceError('not_found');
  if (existing.inviterUserId === userId) throw new FriendServiceError('self');
  if (existing.revokedAt || existing.status === 'revoked') throw new FriendServiceError('revoked');
  if (existing.expiresAt.getTime() <= now.getTime() || existing.status === 'expired') {
    throw new FriendServiceError('expired');
  }
  if (existing.status === 'accepted') {
    if (existing.acceptedUserId !== userId) throw new FriendServiceError('already_claimed');
    return { friendship: await friendshipFor(existing.inviterUserId, userId) };
  }

  const [firstUserId, secondUserId] = canonicalFriendPair(existing.inviterUserId, userId);
  const accepted = await db.transaction(async (tx) => {
    const claimed = await tx
      .update(friendInvitations)
      .set({ status: 'accepted', acceptedUserId: userId, acceptedAt: now })
      .where(and(
        eq(friendInvitations.tokenHash, capabilityTokenHash(token)),
        eq(friendInvitations.status, 'pending'),
        gt(friendInvitations.expiresAt, now),
      ))
      .returning({ tokenHash: friendInvitations.tokenHash });
    if (claimed.length === 0) return false;
    await tx
      .insert(friendships)
      .values({ firstUserId, secondUserId, createdAt: now })
      .onConflictDoNothing();
    return true;
  });
  if (!accepted) throw new FriendServiceError('already_claimed');
  return { friendship: await friendshipFor(existing.inviterUserId, userId) };
}

export async function listFriends(userId: string): Promise<{ friends: Friendship[] }> {
  const second = alias(users, 'friend_second_user');
  const first = alias(users, 'friend_first_user');
  const [asFirst, asSecond] = await Promise.all([
    db
      .select({ userId: second.id, name: second.name, createdAt: friendships.createdAt })
      .from(friendships)
      .innerJoin(second, eq(friendships.secondUserId, second.id))
      .where(eq(friendships.firstUserId, userId)),
    db
      .select({ userId: first.id, name: first.name, createdAt: friendships.createdAt })
      .from(friendships)
      .innerJoin(first, eq(friendships.firstUserId, first.id))
      .where(eq(friendships.secondUserId, userId)),
  ]);
  return {
    friends: [...asFirst, ...asSecond]
      .map((row) => ({
        userId: row.userId,
        displayName: displayName(row.name),
        initials: friendInitials(displayName(row.name)),
        friendsSince: row.createdAt.toISOString(),
      }))
      .sort((left, right) => left.displayName.localeCompare(right.displayName, 'fr')),
  };
}

export async function removeFriend(userId: string, otherUserId: string): Promise<boolean> {
  const [firstUserId, secondUserId] = canonicalFriendPair(userId, otherUserId);
  const rows = await db
    .delete(friendships)
    .where(and(
      eq(friendships.firstUserId, firstUserId),
      eq(friendships.secondUserId, secondUserId),
    ))
    .returning({ firstUserId: friendships.firstUserId });
  return rows.length > 0;
}

export async function areFriends(firstUser: string, secondUser: string): Promise<boolean> {
  if (firstUser === secondUser) return false;
  const [firstUserId, secondUserId] = canonicalFriendPair(firstUser, secondUser);
  const rows = await db
    .select({ firstUserId: friendships.firstUserId })
    .from(friendships)
    .where(and(
      eq(friendships.firstUserId, firstUserId),
      eq(friendships.secondUserId, secondUserId),
    ))
    .limit(1);
  return rows.length === 1;
}

async function invitationWithInviter(token: string) {
  const rows = await db
    .select({
      id: friendInvitations.id,
      tokenHash: friendInvitations.tokenHash,
      idempotencyKey: friendInvitations.idempotencyKey,
      inviterUserId: friendInvitations.inviterUserId,
      acceptedUserId: friendInvitations.acceptedUserId,
      status: friendInvitations.status,
      createdAt: friendInvitations.createdAt,
      expiresAt: friendInvitations.expiresAt,
      acceptedAt: friendInvitations.acceptedAt,
      revokedAt: friendInvitations.revokedAt,
      inviterName: users.name,
    })
    .from(friendInvitations)
    .innerJoin(users, eq(friendInvitations.inviterUserId, users.id))
    .where(eq(friendInvitations.tokenHash, capabilityTokenHash(token)))
    .limit(1);
  return rows[0];
}

async function userById(userId: string) {
  const rows = await db
    .select({ id: users.id, name: users.name })
    .from(users)
    .where(eq(users.id, userId))
    .limit(1);
  return rows[0];
}

async function friendshipFor(friendUserId: string, currentUserId: string): Promise<Friendship> {
  const [friend, rows] = await Promise.all([
    userById(friendUserId),
    db
      .select({ createdAt: friendships.createdAt })
      .from(friendships)
      .where(or(
        and(eq(friendships.firstUserId, friendUserId), eq(friendships.secondUserId, currentUserId)),
        and(eq(friendships.firstUserId, currentUserId), eq(friendships.secondUserId, friendUserId)),
      ))
      .limit(1),
  ]);
  if (!friend || !rows[0]) throw new FriendServiceError('not_found');
  const name = displayName(friend.name);
  return {
    userId: friend.id,
    displayName: name,
    initials: friendInitials(name),
    friendsSince: rows[0].createdAt.toISOString(),
  };
}

function friendInvitation(row: FriendInvitationRow, inviterName: string): FriendInvitation {
  return {
    id: row.id,
    inviterDisplayName: displayName(inviterName),
    status: row.status,
    expiresAt: row.expiresAt.toISOString(),
    createdAt: row.createdAt.toISOString(),
  };
}

function invitationPublicStatus(
  row: Pick<FriendInvitationRow, 'status' | 'expiresAt' | 'revokedAt'>,
  now: Date,
): 'available' | 'expired' | 'revoked' {
  if (row.revokedAt || row.status === 'revoked') return 'revoked';
  if (row.expiresAt.getTime() <= now.getTime() || row.status === 'expired') return 'expired';
  return row.status === 'pending' ? 'available' : 'revoked';
}

function displayName(name: string): string {
  return name.trim() || 'Ami Via';
}

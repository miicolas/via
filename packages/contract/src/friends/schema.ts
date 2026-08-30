import * as z from 'zod';

import { capabilityTokenSchema } from '../shared/schema';

export const friendInvitationTokenSchema = capabilityTokenSchema('friend invitation token');

export const friendshipSchema = z.object({
  userId: z.string().min(1).max(500),
  displayName: z.string().trim().min(1).max(80),
  initials: z.string().trim().min(1).max(4),
  friendsSince: z.iso.datetime({ offset: true }),
});

export const friendInvitationStatusSchema = z.enum([
  'pending',
  'accepted',
  'revoked',
  'expired',
]);

export const friendInvitationSchema = z.object({
  id: z.uuid(),
  inviterDisplayName: z.string().trim().min(1).max(80),
  status: friendInvitationStatusSchema,
  expiresAt: z.iso.datetime({ offset: true }),
  createdAt: z.iso.datetime({ offset: true }),
});

export const friendInvitationCreateInputSchema = z.object({
  idempotencyKey: z.uuid(),
});

export const friendInvitationCreateResponseSchema = z.object({
  invitation: friendInvitationSchema,
  token: friendInvitationTokenSchema,
  url: z.url(),
});

export const friendInvitationPreviewInputSchema = z.object({
  token: friendInvitationTokenSchema,
});

export const friendInvitationPreviewResponseSchema = z.object({
  inviterDisplayName: z.string().trim().min(1).max(80),
  status: z.enum(['available', 'expired', 'revoked']),
  expiresAt: z.iso.datetime({ offset: true }),
});

export const friendInvitationAcceptInputSchema = z.object({
  token: friendInvitationTokenSchema,
});

export const friendInvitationAcceptResponseSchema = z.object({
  friendship: friendshipSchema,
});

export const friendsListInputSchema = z.object({});
export const friendsListResponseSchema = z.object({
  friends: z.array(friendshipSchema).max(1_000),
});

export const friendRemoveInputSchema = z.object({
  userId: z.string().min(1).max(500),
});
export const friendRemoveResponseSchema = z.object({ removed: z.boolean() });

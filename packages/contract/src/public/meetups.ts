import * as z from 'zod';

export const publicMeetupInvitationResponseSchema = z.strictObject({
  organizerDisplayName: z.string().trim().min(1).max(80),
  destination: z.strictObject({
    id: z.string().min(1).max(500),
    name: z.string().trim().min(1).max(300),
  }),
  targetArrivalAt: z.iso.datetime({ offset: true }),
  status: z.enum(['available', 'full', 'expired', 'revoked']),
  expiresAt: z.iso.datetime({ offset: true }),
});

export const publicFriendInvitationResponseSchema = z.strictObject({
  inviterDisplayName: z.string().trim().min(1).max(80),
  status: z.enum(['available', 'expired', 'revoked']),
  expiresAt: z.iso.datetime({ offset: true }),
});

export type PublicMeetupInvitationResponse = z.infer<
  typeof publicMeetupInvitationResponseSchema
>;
export type PublicFriendInvitationResponse = z.infer<
  typeof publicFriendInvitationResponseSchema
>;

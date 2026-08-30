import type { z } from 'zod';
import type { friendInvitationPreviewResponseSchema } from '@via/contract';
import {
  publicFriendInvitationResponseSchema,
  type PublicFriendInvitationResponse,
} from '@via/contract/public';

/** The private preview shape, typed by the contract so drift cannot compile. */
type FriendInvitationPreview = z.infer<typeof friendInvitationPreviewResponseSchema>;

/** Explicit public allowlist required by ADR-0003. */
export function toPublicFriendInvitation(
  preview: FriendInvitationPreview,
): PublicFriendInvitationResponse {
  return publicFriendInvitationResponseSchema.parse({
    inviterDisplayName: preview.inviterDisplayName,
    status: preview.status,
    expiresAt: preview.expiresAt,
  });
}

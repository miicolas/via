import type { MeetupInvitationPreview } from '@via/contract';
import {
  publicMeetupInvitationResponseSchema,
  type PublicMeetupInvitationResponse,
} from '@via/contract/public';

/** Explicit public allowlist required by ADR-0003. */
export function toPublicMeetupInvitation(
  preview: MeetupInvitationPreview,
): PublicMeetupInvitationResponse {
  return publicMeetupInvitationResponseSchema.parse({
    organizerDisplayName: preview.organizerDisplayName,
    destination: {
      id: preview.destination.id,
      name: preview.destination.name,
    },
    targetArrivalAt: preview.targetArrivalAt,
    status: preview.status,
    expiresAt: preview.expiresAt,
  });
}

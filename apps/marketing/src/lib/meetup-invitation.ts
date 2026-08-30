import {
  publicMeetupInvitationResponseSchema,
  type PublicMeetupInvitationResponse,
} from "@via/contract/public";

import { fetchInvitation, type InvitationResult } from "@/lib/invitation/fetch-invitation";

export type MeetupInvitationResult = InvitationResult<PublicMeetupInvitationResponse>;

export function fetchMeetupInvitation(
  token: string,
  signal?: AbortSignal,
): Promise<MeetupInvitationResult> {
  return fetchInvitation({
    path: "public/meetup-invitations",
    token,
    schema: publicMeetupInvitationResponseSchema,
    signal,
  });
}

import {
  publicFriendInvitationResponseSchema,
  type PublicFriendInvitationResponse,
} from "@via/contract/public";

import { fetchInvitation, type InvitationResult } from "@/lib/invitation/fetch-invitation";

export type FriendInvitationResult = InvitationResult<PublicFriendInvitationResponse>;

export function fetchFriendInvitation(
  token: string,
  signal?: AbortSignal,
): Promise<FriendInvitationResult> {
  return fetchInvitation({
    path: "public/friend-invitations",
    token,
    schema: publicFriendInvitationResponseSchema,
    signal,
  });
}

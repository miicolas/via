import { friendInvitationTokenSchema } from '@via/contract';

import { FriendServiceError, previewFriendInvitation } from '../../routers/friends/service';
import { capabilityLinkRouter } from '../capability-link-router';
import { toPublicFriendInvitation } from './projection';

/**
 * A live invitation carries `expired`/`revoked` inside its 200 payload — the
 * page renders those states — so the error rows below only answer for a token
 * the service refuses outright.
 */
export const publicFriendInvitationsRouter = capabilityLinkRouter({
  tokenSchema: friendInvitationTokenSchema,
  load: previewFriendInvitation,
  project: toPublicFriendInvitation,
  isServiceError: (error): error is FriendServiceError => error instanceof FriendServiceError,
  errors: {
    not_found: { code: 'friend_invitation_not_found', message: 'Cette invitation est introuvable.' },
    revoked: { code: 'friend_invitation_revoked', message: 'Cette invitation a été retirée.' },
    expired: { code: 'friend_invitation_expired', message: 'Cette invitation a expiré.' },
    corrupt: {
      code: 'friend_invitation_unavailable',
      message: 'Cette invitation est temporairement indisponible.',
    },
  },
  cacheControl: 'public, max-age=30, s-maxage=30',
});

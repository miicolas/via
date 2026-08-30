import { meetupTokenSchema } from '@via/contract';

import { MeetupServiceError } from '../../routers/meetups/errors';
import { getMeetupInvitationPreview } from '../../routers/meetups/service';
import { capabilityLinkRouter } from '../capability-link-router';
import { toPublicMeetupInvitation } from './projection';

/**
 * A live invitation carries `expired`/`revoked`/`full` inside its 200 payload
 * — the page renders those states — so the error rows below only answer for a
 * token the service refuses outright.
 */
export const publicMeetupInvitationsRouter = capabilityLinkRouter({
  tokenSchema: meetupTokenSchema,
  load: getMeetupInvitationPreview,
  project: toPublicMeetupInvitation,
  isServiceError: (error): error is MeetupServiceError => error instanceof MeetupServiceError,
  errors: {
    not_found: { code: 'meetup_invitation_not_found', message: 'Cette invitation est introuvable.' },
    revoked: { code: 'meetup_invitation_revoked', message: 'Cette invitation a été retirée.' },
    expired: { code: 'meetup_invitation_expired', message: 'Cette invitation a expiré.' },
    corrupt: {
      code: 'meetup_invitation_unavailable',
      message: 'Cette invitation est temporairement indisponible.',
    },
  },
  cacheControl: 'public, max-age=30, s-maxage=30',
});

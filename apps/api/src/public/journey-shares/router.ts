import { journeyShareTokenSchema } from '@via/contract';

import {
  getJourneyShare,
  JourneyShareLookupError,
} from '../../routers/journey-shares/service';
import { capabilityLinkRouter } from '../capability-link-router';
import { toPublicJourneyShare } from './projection';

/**
 * Browser-facing projection for `/trip/[token]`. It intentionally reuses the
 * service's validated output but stays outside the oRPC contract, in line with
 * ADR-0003: the public surface is a hand-written projection, not a private
 * application response forwarded wholesale.
 */
export const publicJourneySharesRouter = capabilityLinkRouter({
  tokenSchema: journeyShareTokenSchema,
  load: getJourneyShare,
  project: toPublicJourneyShare,
  isServiceError: (error): error is JourneyShareLookupError =>
    error instanceof JourneyShareLookupError,
  errors: {
    not_found: { code: 'journey_share_not_found', message: 'Ce lien de trajet est introuvable.' },
    revoked: { code: 'journey_share_revoked', message: 'Ce lien de trajet a été supprimé.' },
    expired: { code: 'journey_share_expired', message: 'Ce lien de trajet a expiré.' },
    corrupt: {
      code: 'journey_share_unavailable',
      message: 'Ce trajet est temporairement indisponible.',
    },
  },
  cacheControl: 'public, max-age=60, s-maxage=60, stale-while-revalidate=300',
});

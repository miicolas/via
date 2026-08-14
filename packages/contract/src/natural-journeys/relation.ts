import { oc } from '@orpc/contract';

import { naturalJourneyInputSchema, naturalJourneyResponseSchema } from './schema';

export const naturalJourneysSubmitRelation = oc
  .route({
    method: 'POST',
    path: '/natural-journeys',
    summary: 'Comprendre et calculer un itinéraire en langage naturel',
    description:
      'Interprète une phrase française, clarifie les lieux ou le sens temporel si nécessaire, puis calcule un itinéraire vérifié.',
    tags: ['natural-journeys'],
  })
  .input(naturalJourneyInputSchema)
  .output(naturalJourneyResponseSchema);

import { oc } from '@orpc/contract';

import { journeyInputSchema, journeysResponseSchema } from './schema';

export const journeysPlanRelation = oc
  .route({
    method: 'GET',
    path: '/journeys',
    summary: 'Calculer des itinéraires',
    description:
      'Calcule plusieurs itinéraires depuis la position courante vers une station ou une adresse. ' +
      'Les horaires en direct restent réservés au panneau de départs de la station proche.',
    tags: ['journeys'],
  })
  .input(journeyInputSchema)
  .output(journeysResponseSchema);

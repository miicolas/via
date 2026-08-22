import { oc } from '@orpc/contract';

import {
  journeyDepartureChoicesInputSchema,
  journeyDepartureChoicesResponseSchema,
  journeyInputSchema,
  journeysResponseSchema,
} from './schema';

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

export const journeyDepartureChoicesRelation = oc
  .route({
    method: 'POST',
    path: '/journeys/departure-choices',
    summary: 'Actualiser ou choisir un passage dans un trajet',
    description:
      'Retourne le passage retenu et le suivant pour chaque tronçon de transport. ' +
      'Une sélection conserve les étapes en amont et recalcule tout l\'aval.',
    tags: ['journeys'],
  })
  .input(journeyDepartureChoicesInputSchema)
  .output(journeyDepartureChoicesResponseSchema);

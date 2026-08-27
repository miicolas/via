import { oc } from '@orpc/contract';

import { departuresInputSchema, departuresResponseSchema } from './schema';

export const departuresForStationRelation = oc
  .route({
    method: 'GET',
    path: '/departures',
    summary: 'Prochains passages',
    description:
      'Prochains départs par ligne et destination pour une station, en temps réel ' +
      '(PRIM Île-de-France Mobilités) quand la source répond, sinon selon les horaires disponibles. ' +
      'Avec `routeId`, la réponse devient le tableau complet de la ligne jusqu’à la fin du service. ' +
      '`source` dit ce que les horodatages valent.',
    tags: ['departures'],
  })
  .input(departuresInputSchema)
  .output(departuresResponseSchema);

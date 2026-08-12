import { oc } from '@orpc/contract';

import { departuresInputSchema, departuresResponseSchema } from './schema';

export const departuresForStationRelation = oc
  .route({
    method: 'GET',
    path: '/departures',
    summary: 'Prochains passages',
    description:
      'Prochains départs par ligne et destination pour une station, en temps réel ' +
      "(PRIM Île-de-France Mobilités) quand la source répond, sinon à l'horaire théorique. " +
      '`source` dit ce que les horodatages valent.',
    tags: ['departures'],
  })
  .input(departuresInputSchema)
  .output(departuresResponseSchema);

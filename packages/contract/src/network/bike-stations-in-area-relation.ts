import { oc } from '@orpc/contract';

import { bikeStationsInAreaSchema, stationsInAreaInputSchema } from './schema';

export const bikeStationsInAreaRelation = oc
  .route({
    method: 'GET',
    path: '/network/bike-stations',
    summary: 'Les stations Vélib’ d’une zone',
    description:
      'Les stations Vélib’ d’une petite boîte englobante, avec leur inventaire du moment. ' +
      'Même découpage en tuiles que `stationsInArea`, mais une fraîcheur à la minute : ' +
      'la couche est optionnelle côté client et ne doit pas rythmer le cache des stations.',
    tags: ['network'],
  })
  .input(stationsInAreaInputSchema)
  .output(bikeStationsInAreaSchema);

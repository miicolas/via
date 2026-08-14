import { oc } from '@orpc/contract';

import { stationsInAreaInputSchema, stationsInAreaSchema } from './schema';

export const stationsInAreaRelation = oc
  .route({
    method: 'GET',
    path: '/network/stations',
    summary: 'Les stations d’une zone',
    description:
      'Toutes les stations (bus compris) dans une petite boîte englobante, avec les badges ' +
      'des lignes qui les desservent. Pensé pour être appelé tuile par tuile pendant que la ' +
      'carte bouge : beaucoup de petites requêtes cachables plutôt qu’un seul payload énorme.',
    tags: ['network'],
  })
  .input(stationsInAreaInputSchema)
  .output(stationsInAreaSchema);

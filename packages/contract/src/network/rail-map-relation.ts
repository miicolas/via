import { oc } from '@orpc/contract';

import { railMapSchema } from './schema';

export const railMapRelation = oc
  .route({
    method: 'GET',
    path: '/network/rail-map',
    summary: 'Le réseau ferré visible',
    description:
      'Lignes de métro, RER, Transilien et tram avec leurs polylignes et toutes leurs stations. ' +
      'La donnée ne change qu’à l’import GTFS — cache long. ' +
      'Les arrêts de bus se chargent par zone via `stationsInArea`.',
    tags: ['network'],
  })
  .output(railMapSchema);

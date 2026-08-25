import { oc } from '@orpc/contract';

import { railMapSchema } from './schema';

/** One source for the REST and oRPC cache mounts around this large payload. */
export const RAIL_MAP_PATH = '/network/rail-map' as const;
export const RAIL_MAP_RPC_PATH = '/network/railMap' as const;

export const railMapRelation = oc
  .route({
    method: 'GET',
    path: RAIL_MAP_PATH,
    summary: 'Le réseau ferré visible',
    description:
      'Lignes de métro, RER, Transilien et tram avec leurs polylignes et toutes leurs stations. ' +
      'La donnée ne change qu’à l’import GTFS — cache long. ' +
      'Les arrêts de bus se chargent par zone via `stationsInArea`.',
    tags: ['network'],
  })
  .output(railMapSchema);

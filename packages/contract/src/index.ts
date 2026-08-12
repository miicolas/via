import { oc } from '@orpc/contract';

import {
  healthSchema,
  networkMapSchema,
  searchInputSchema,
  searchResponseSchema,
} from './schemas';


const health = oc
  .route({
    method: 'GET',
    path: '/health',
    summary: 'Liveness probe',
    description: 'Reports whether the API can reach Postgres.',
    tags: ['system'],
  })
  .output(healthSchema);

const networkMap = oc
  .route({
    method: 'GET',
    path: '/network/map',
    summary: 'The whole metro network',
    description:
      'Every metro line with its polylines, and every station with one position per line it serves. Cached for five minutes.',
    tags: ['network'],
  })
  .output(networkMapSchema);

const searchQuery = oc
  .route({
    method: 'GET',
    path: '/search',
    summary: 'Recherche unifiée',
    description:
      'Stations de métro et adresses françaises (géocodage BAN) en une seule liste classée. ' +
      'Avec une position, chaque résultat porte sa distance en mètres.',
    tags: ['search'],
  })
  .input(searchInputSchema)
  .output(searchResponseSchema);

export const contract = {
  health,
  network: {
    map: networkMap,
  },
  search: {
    query: searchQuery,
  },
};

export * from './schemas';

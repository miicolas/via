import { oc } from '@orpc/contract';

import { searchInputSchema, searchResponseSchema } from './schema';

export const searchQueryRelation = oc
  .route({
    method: 'GET',
    path: '/search',
    summary: 'Recherche unifiée',
    description:
      'Arrêts de métro, RER, Transilien, tram et bus, stations Vélib’ filtrées et adresses d’Île-de-France (géocodage BAN) en une seule liste classée. ' +
      'Avec une position, chaque résultat porte sa distance en mètres.',
    tags: ['search'],
  })
  .input(searchInputSchema)
  .output(searchResponseSchema);

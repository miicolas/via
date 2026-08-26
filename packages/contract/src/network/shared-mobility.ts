import { oc } from '@orpc/contract';

import { sharedMobilityInAreaSchema, stationsInAreaInputSchema } from './schema';

/**
 * One normalized map payload for all shared-mobility providers. The app never
 * needs to know which GBFS version or feed URL supplied an item.
 */
export const sharedMobilityInAreaRelation = oc
  .route({
    method: 'GET',
    path: '/network/shared-mobility',
    summary: 'Les véhicules et stations de mobilité partagée d’une zone',
    description:
      'Les vélos et trottinettes actuellement louables de Dott/TIER, Lime et YEGO, ' +
      'ainsi que les stations Vélib’ avec leur inventaire. Les données expirées et les ' +
      'véhicules réservés ou désactivés sont masqués. Le statut de chaque source est ' +
      'retourné séparément pour qu’une panne d’opérateur ne masque pas les autres.',
    tags: ['network'],
  })
  .input(stationsInAreaInputSchema)
  .output(sharedMobilityInAreaSchema);

import { oc } from '@orpc/contract';

import {
  accountDeleteInputSchema,
  accountDeleteResponseSchema,
  accountSyncInputSchema,
  accountSyncResponseSchema,
} from './schema';

export const accountSyncRelation = oc
  .route({
    method: 'POST',
    path: '/account/sync',
    summary: 'Synchroniser les données du compte',
    description:
      'Applique des opérations idempotentes puis renvoie les favoris, recherches et préférences canoniques.',
    tags: ['account'],
  })
  .input(accountSyncInputSchema)
  .output(accountSyncResponseSchema);

export const accountDeleteRelation = oc
  .route({
    method: 'POST',
    path: '/account/delete',
    summary: 'Supprimer le compte Via',
    description:
      'Réauthentifie avec Apple, révoque le jeton Apple puis supprime toutes les données du compte.',
    tags: ['account'],
  })
  .input(accountDeleteInputSchema)
  .output(accountDeleteResponseSchema);

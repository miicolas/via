import { oc } from '@orpc/contract';

import {
  lineDetailInputSchema,
  lineDetailResponseSchema,
  lineSearchInputSchema,
  lineStatusesResponseSchema,
} from './schema';

export const lineStatusesRelation = oc
  .route({
    method: 'GET',
    path: '/lines/statuses',
    summary: 'État des lignes ferrées',
    description:
      'Toutes les lignes de métro, RER, Transilien et tram avec leur niveau de service, ' +
      'issu du flux perturbations IDFM rafraîchi côté serveur. ' +
      '`source` dit si le flux a répondu ; `upcoming` annonce une fermeture prévue sous sept jours.',
    tags: ['lines'],
  })
  .output(lineStatusesResponseSchema);

export const lineSearchRelation = oc
  .route({
    method: 'GET',
    path: '/lines/search',
    summary: 'Recherche de lignes',
    description:
      'Lignes de tous modes — bus compris — dont le code ou le nom correspond à la requête, ' +
      'avec le même niveau de service que `statuses`.',
    tags: ['lines'],
  })
  .input(lineSearchInputSchema)
  .output(lineStatusesResponseSchema);

export const lineDetailRelation = oc
  .route({
    method: 'GET',
    path: '/lines/detail',
    summary: 'Détail d’une ligne',
    description:
      'Les branches de la ligne avec leurs stations en ordre de parcours, et ses perturbations ' +
      'actives puis à venir sous sept jours — tronçons impactés compris, résolubles contre les stations.',
    tags: ['lines'],
  })
  .input(lineDetailInputSchema)
  .output(lineDetailResponseSchema);

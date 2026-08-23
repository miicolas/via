import { oc } from '@orpc/contract';

import {
  reportSubmissionInputSchema,
  reportSubmissionResponseSchema,
  stationStatusInputSchema,
  stationStatusSchema,
} from './schema';

export const reportSubmitRelation = oc
  .route({
    method: 'POST',
    path: '/reports',
    summary: 'Envoyer un signalement',
    description: 'Enregistre une observation idempotente et renvoie l’état vivant agrégé de la station.',
    tags: ['reports'],
  })
  .input(reportSubmissionInputSchema)
  .output(reportSubmissionResponseSchema);

export const stationStatusRelation = oc
  .route({
    method: 'GET',
    path: '/reports/station-status',
    summary: 'État vivant d’une station',
    description: 'Fusionne les données automatiques et les observations communautaires encore actives.',
    tags: ['reports'],
  })
  .input(stationStatusInputSchema)
  .output(stationStatusSchema);

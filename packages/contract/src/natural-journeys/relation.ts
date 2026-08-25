import { oc } from '@orpc/contract';

import { naturalJourneyInputSchema, naturalJourneyResultSchema } from './schema';

export const naturalJourneysSubmitRelation = oc
  .route({
    method: 'POST',
    path: '/natural-journeys',
    summary: 'Interpréter une phrase de trajet',
    description:
      "Adapter d'interprétation du repli serveur : reçoit une phrase, les ancres " +
      'déterministes et des alias personnels opaques, puis renvoie le même patch ' +
      'typé que le modèle local. La résolution et la planification restent sur l’appareil.',
    tags: ['natural-journeys'],
  })
  .input(naturalJourneyInputSchema)
  .output(naturalJourneyResultSchema);

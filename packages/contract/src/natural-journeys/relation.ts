import { oc } from '@orpc/contract';

import { naturalJourneyInputSchema, naturalJourneyResultSchema } from './schema';

export const naturalJourneysSubmitRelation = oc
  .route({
    method: 'POST',
    path: '/natural-journeys',
    summary: 'Interpréter une phrase et calculer un itinéraire',
    description:
      "Point d'entrée du repli serveur : reçoit une phrase en langage naturel, " +
      "sa position éventuelle et le contexte temporel, puis renvoie le même résultat " +
      "structuré que le chemin local. Réservé aux soumissions initiales — les " +
      'clarifications restent traitées sur l’appareil.',
    tags: ['natural-journeys'],
  })
  .input(naturalJourneyInputSchema)
  .output(naturalJourneyResultSchema);

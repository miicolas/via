import { oc } from '@orpc/contract';

import { stationCrowdingInputSchema, stationCrowdingSchema } from './schema';

export const stationCrowdingRelation = oc
  .route({
    method: 'GET',
    path: '/network/station-crowding',
    summary: 'L’affluence habituelle d’une station',
    description:
      'Le profil horaire habituel des validations IDFM sur 24 heures, pour les trois types de ' +
      'jour que la source distingue : semaine, samedi, dimanche et fériés. Un profil type mis à ' +
      'jour chaque trimestre, pas du temps réel — et réseau ferré uniquement : une station de ' +
      'bus répond sans profil.',
    tags: ['network'],
  })
  .input(stationCrowdingInputSchema)
  .output(stationCrowdingSchema);

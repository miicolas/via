import { oc } from '@orpc/contract';

import { networkMapSchema } from './schema';

export const networkMapRelation = oc
  .route({
    method: 'GET',
    path: '/network/map',
    summary: 'The whole metro network',
    description:
      'Every metro line with its polylines, and every station with one position per line it serves. Cached for five minutes.',
    tags: ['network'],
  })
  .output(networkMapSchema);

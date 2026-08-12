import { oc } from '@orpc/contract';

import { networkMapSchema } from './schema';

export const networkMapRelation = oc
  .route({
    method: 'GET',
    path: '/network/map',
    summary: 'The whole visible transit network',
    description:
      'Metro and RER lines with their polylines, bus lines without polylines, and every served stop. Cached for five minutes.',
    tags: ['network'],
  })
  .output(networkMapSchema);

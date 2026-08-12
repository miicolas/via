import { oc } from '@orpc/contract';

import { healthSchema } from './schema';

export const healthRelation = oc
  .route({
    method: 'GET',
    path: '/health',
    summary: 'Liveness probe',
    description: 'Reports whether the API can reach Postgres.',
    tags: ['system'],
  })
  .output(healthSchema);

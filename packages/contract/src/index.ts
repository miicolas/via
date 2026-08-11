import { oc } from '@orpc/contract';

import { healthSchema, networkMapSchema } from './schemas';

/**
 * The API contract: paths, methods and payload shapes, with no server code
 * behind them and no client code in front.
 *
 * This is the seam that replaced `hc<AppType>`. Under that scheme the app got its
 * types by compiling the API's *source*, which dragged drizzle, PostGIS SQL
 * templates and the whole database layer into the mobile typecheck. Here both
 * sides depend on this package instead, and on nothing of each other's.
 *
 * The paths are the ones the app already called, so the wire is unchanged.
 */

const health = oc
  .route({
    method: 'GET',
    path: '/health',
    summary: 'Liveness probe',
    description: 'Reports whether the API can reach Postgres.',
    tags: ['system'],
  })
  .output(healthSchema);

const networkMap = oc
  .route({
    method: 'GET',
    path: '/network/map',
    summary: 'The whole metro network',
    description:
      'Every metro line with its polylines, and every station with one position per line it serves. Cached for five minutes.',
    tags: ['network'],
  })
  .output(networkMapSchema);

export const contract = {
  health,
  network: {
    map: networkMap,
  },
};

export * from './schemas';

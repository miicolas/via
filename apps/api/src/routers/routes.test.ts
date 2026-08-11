import { expect, test } from 'bun:test';

import { app } from '../app';

/**
 * The mobile client addresses routes by path string (`api.api.network.map.$get`),
 * so a moved mount point is a production break that a type error does not always
 * catch — the client would simply request a path nobody serves.
 *
 * This asserts the whole public surface. Importing `app` pulls in `@via/db`,
 * whose postgres-js client connects lazily, so no query runs and no database is
 * needed.
 *
 * `app.routes` holds one entry per *handler*, so a route fronted by middleware
 * (as `/api/network/map` is, by `cacheControl`) appears more than once. The set
 * collapses that back to the surface a caller actually sees.
 */
test('the public route table is stable', () => {
  const paths = new Set(
    app.routes
      .filter((route) => route.method !== 'ALL')
      .map((route) => `${route.method} ${route.path}`)
  );

  expect([...paths].sort()).toEqual(['GET /api/health', 'GET /api/network/map']);
});

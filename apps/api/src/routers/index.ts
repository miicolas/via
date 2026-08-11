import { Hono } from 'hono';

import type { AppEnv } from '../http/app-env';
import { healthRouter } from './health/router';
import { networkRouter } from './network/router';

/**
 * Mounted at `/api` by the root app. Each sub-router declares only the path below
 * its own prefix, so adding a feature is one folder plus one line here — and
 * `app.ts` never has to change again.
 *
 * The mount is a single chained expression because that is what carries the full
 * route table into `AppType`.
 */
export const apiRouter = new Hono<AppEnv>()
  .route('/health', healthRouter)
  .route('/network', networkRouter);

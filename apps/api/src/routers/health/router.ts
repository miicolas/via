import { Hono } from 'hono';

import type { AppEnv } from '../../http/app-env';
import { getHealthHandlers } from './handlers/get-health';

/**
 * Mounted at `/api/health`, so the path here is `/` — Hono's `MergePath` folds
 * `'/health' + '/'` back to `/health`, without a trailing slash.
 */
export const healthRouter = new Hono<AppEnv>().get('/', ...getHealthHandlers);

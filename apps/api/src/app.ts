import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { requestId } from 'hono/request-id';

import type { AppEnv } from './http/app-env';
import { onError } from './http/error-handler';
import { notFound } from './http/not-found';
import { apiRouter } from './routers';

const app = new Hono<AppEnv>();

app.use(requestId());
app.use(logger());
app.use('/api/*', cors());

/**
 * The whole route table has to come out of a single chained expression: `AppType`
 * is what the mobile app's `hc<AppType>` client is built from, and a
 * statement-per-route version would type as a bare `Hono`, silently degrading the
 * client to `any`.
 *
 * Sub-routers keep that property — `.route()` folds the child's schema into the
 * parent's, so `/network` + `/map` under `/api` still resolves to the path
 * `/api/network/map` and the client call stays `api.api.network.map.$get`.
 */
const routes = app.route('/api', apiRouter);

/**
 * Registered off the route chain on purpose: both are app-wide and belong to no
 * route's schema, so folding them into the chain would only widen `AppType`.
 */
app.onError(onError);
app.notFound(notFound);

export { app };
export type AppType = typeof routes;

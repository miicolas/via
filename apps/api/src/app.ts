import { type Context, Hono, type Next } from 'hono';
import { cors } from 'hono/cors';
import { compress } from 'hono/compress';
import { etag } from 'hono/etag';
import { logger } from 'hono/logger';
import { requestId } from 'hono/request-id';

import type { AppEnv } from './http/app-env';
import { onError } from './http/error-handler';
import { notFound } from './http/not-found';
import type { FetchHandler } from '@orpc/server/fetch';

import { openApiHandler, rpcHandler } from './orpc/handler';
import type { ApiContext } from './orpc/implementer';
import { getOpenApiDocument } from './orpc/openapi';
import { auth } from './auth/auth';
import { requireAuth } from './auth/session';
import { redis } from './redis';
import { transitNetworkCacheVersion } from './routers/departures/network-version';
import { versionedPayloadCache } from './http/versioned-payload-cache';

const app = new Hono<AppEnv>();

app.use(requestId());
app.use(logger());
app.use('/api/*', compress());
app.use('/rpc/*', compress());
app.use('/api/*', cors());
app.use('/rpc/*', cors());
/** Better Auth keeps its native ID-token flow outside the oRPC contract. */
app.on(['GET', 'POST'], '/api/auth/*', (c) => auth.handler(c.req.raw));

app.use('/api/*', requireAuth);
app.use('/rpc/*', requireAuth);

/**
 * The rail map is the one payload big enough for re-encoding it per request to
 * show up: 1.14 MB that only changes when a GTFS import bumps the network
 * version. Mounted here — inside `compress()`, outside `etag()` — so the miss
 * path still produces hono's own ETag while hits skip the handler, the zod
 * revalidation, the digest and the gzip entirely. Both transports serve the
 * same procedure, so both get their own entry.
 */
const railMapCache = versionedPayloadCache(() => transitNetworkCacheVersion(redis));
app.use('/api/network/rail-map', railMapCache);
app.use('/rpc/network/railMap', railMapCache);

app.use('/api/*', etag());
app.use('/rpc/*', etag());

/** The contract, as a document. Handy for clients that are not this repo's app. */
app.get('/api/openapi.json', async (c) => c.json(await getOpenApiDocument()));

/**
 * Hono keeps the HTTP edge — logging, CORS, request ids, error envelope — and
 * oRPC owns the two mounts below, both dispatching to the same implemented
 * contract.
 *
 * `matched: false` means no procedure claimed the path, so the request falls
 * through to Hono's `notFound` rather than being swallowed here.
 */
function mount(handler: FetchHandler<ApiContext>, prefix: '/api' | '/rpc') {
  return async (c: Context<AppEnv>, next: Next) => {
    const authSession = c.var.authSession;
    const { matched, response } = await handler.handle(c.req.raw, {
      prefix,
      context: {
        userId: authSession?.user.id,
        isAnonymous: authSession?.user.isAnonymous ?? undefined,
      },
    });

    if (matched) return response;

    await next();
  };
}

app.use('/api/*', mount(openApiHandler, '/api'));
app.use('/rpc/*', mount(rpcHandler, '/rpc'));

app.onError(onError);
app.notFound(notFound);

export { app };

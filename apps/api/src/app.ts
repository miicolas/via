import { type Context, Hono, type Next } from 'hono';
import { cors } from 'hono/cors';
import { compress } from 'hono/compress';
import { logger } from 'hono/logger';
import { requestId } from 'hono/request-id';

import type { AppEnv } from './http/app-env';
import { onError } from './http/error-handler';
import { notFound } from './http/not-found';
import type { FetchHandler } from '@orpc/server/fetch';

import { openApiHandler, rpcHandler } from './orpc/handler';
import type { ApiContext } from './orpc/implementer';
import { getOpenApiDocument } from './orpc/openapi';
import { chatHandler } from './routers';

const app = new Hono<AppEnv>();

app.use(requestId());
app.use(logger());
app.use('/api/*', compress());
app.use('/rpc/*', compress());
app.use('/api/*', cors());
app.use('/rpc/*', cors());
// `/ai/*` is deliberately NOT compressed: compression buffers the chat stream.
app.use('/ai/*', cors());

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
function requestIdentity(c: Context<AppEnv>) {
  const forwardedFor = c.req.header('x-forwarded-for')?.split(',')[0]?.trim();
  const identity = c.req.header('x-via-client-id')?.trim() || forwardedFor || 'anonymous';
  return identity.slice(0, 200);
}

function mount(handler: FetchHandler<ApiContext>, prefix: '/api' | '/rpc') {
  return async (c: Context<AppEnv>, next: Next) => {
    const { matched, response } = await handler.handle(c.req.raw, {
      prefix,
      context: { viaIdentity: requestIdentity(c) },
    });

    if (matched) return response;

    await next();
  };
}

app.use('/api/*', mount(openApiHandler, '/api'));
app.use('/rpc/*', mount(rpcHandler, '/rpc'));

/** The streaming chat lives outside oRPC: it answers with a UI-message stream. */
app.post('/ai/chat', (c) => chatHandler(c.req.raw, requestIdentity(c)));

app.onError(onError);
app.notFound(notFound);

export { app };

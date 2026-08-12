import { OpenAPIHandler } from '@orpc/openapi/fetch';
import { RPCHandler } from '@orpc/server/fetch';
import { ResponseHeadersPlugin } from '@orpc/server/plugins';
import { experimental_ZodSmartCoercionPlugin as ZodSmartCoercionPlugin } from '@orpc/zod/zod4';

import { apiRouter } from '../routers';

/**
 * `ResponseHeadersPlugin` is what puts `resHeaders` in the procedure context, so
 * a handler can set `Cache-Control` without importing anything HTTP.
 */
const plugins = () => [new ResponseHeadersPlugin()];

/**
 * Two transports over one router — the procedures, queries and mappers are shared;
 * only the wire format differs.
 *
 * `/api` speaks REST at the paths the contract declares, which is what the
 * OpenAPI document describes, what `check:transit-alignment` calls, and what any
 * consumer that is not this repo's app would reach for.
 */
/**
 * REST query strings arrive as strings — `?latitude=48.86` would fail a
 * `z.number()` without the coercion plugin. `/rpc` doesn't need it: the oRPC
 * protocol carries JSON types natively.
 */
export const openApiHandler = new OpenAPIHandler(apiRouter, {
  plugins: [...plugins(), new ZodSmartCoercionPlugin()],
});

/**
 * `/rpc` speaks oRPC's own protocol, which is what `createORPCClient` in the app
 * talks to. It exists because the generated client is the point of a contract:
 * the app calls `api.network.map()` and never spells a URL.
 *
 * The client is configured to issue `GET`, so the ~890 kB network map stays
 * cacheable by the platform HTTP cache — a POST would silently give that up.
 */
export const rpcHandler = new RPCHandler(apiRouter, { plugins: plugins() });

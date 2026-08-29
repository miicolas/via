import type { Context, MiddlewareHandler } from 'hono';
import { routePath } from 'hono/route';

import type { AppEnv } from './app-env';

/** The closed, request-safe shape emitted by the access logger. */
export type RequestLogEvent = {
  readonly event: 'http_request';
  readonly method: string;
  readonly route: string;
  readonly status: number;
  readonly durationMs: number;
  readonly requestId?: string;
};

export type RequestLogSink = (event: RequestLogEvent) => void;

const productionSink: RequestLogSink = (event) => {
  console.log(JSON.stringify(event));
};

/**
 * Logs only values controlled by Via. In particular, this never serializes the
 * request URL, path, headers, body, response, or thrown error.
 */
export function requestLogger(sink: RequestLogSink = productionSink): MiddlewareHandler<AppEnv> {
  return async function requestLoggerMiddleware(c, next) {
    const startedAt = performance.now();
    let failed = false;

    try {
      await next();
    } catch (error) {
      failed = true;
      throw error;
    } finally {
      const event: RequestLogEvent = {
        event: 'http_request',
        method: c.req.method,
        route: safeRoutePath(c),
        status: failed ? 500 : c.res.status,
        durationMs: Math.max(0, Math.round(performance.now() - startedAt)),
        ...(c.get('requestId') === undefined ? {} : { requestId: c.get('requestId') }),
      };

      try {
        sink(event);
      } catch {
        // Logging must never change the response or mask the original error.
      }
    }
  };
}

function safeRoutePath(c: Context<AppEnv>): string {
  const registered = routePath(c, -1);
  if (registered) return registered;

  // The fallback is deliberately a finite category, not a copy of the path.
  const path = c.req.path;
  if (path === '/api' || path.startsWith('/api/')) return '/api/*';
  if (path === '/rpc' || path.startsWith('/rpc/')) return '/rpc/*';
  if (path === '/public' || path.startsWith('/public/')) return '/public/*';
  return 'unmatched';
}

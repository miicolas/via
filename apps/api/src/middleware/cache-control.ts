import { createMiddleware } from 'hono/factory';

/**
 * Declares a route's caching policy next to the route instead of burying a
 * `c.header(...)` in the middle of building the response body.
 *
 * The header is set *after* `await next()` on purpose: before it, the value goes
 * to Hono's prepared headers, whose merge depends on how the response was
 * constructed. Once the response is finalized, Hono clones it and sets the header
 * on the clone, which always lands.
 *
 * It returns `Promise<void>`, so it contributes nothing to the route's response
 * union and the typed client is unaffected.
 */
export function cacheControl(value: string) {
  return createMiddleware(async (c, next) => {
    await next();
    c.header('Cache-Control', value);
  });
}

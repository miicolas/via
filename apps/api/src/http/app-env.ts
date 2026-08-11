import type { RequestIdVariables } from 'hono/request-id';

/**
 * The shared Hono environment. Every router and every handler factory is
 * parameterised on it, so adding a context variable (auth, tenant, tracing) is
 * one edit here rather than a sweep through every route file.
 *
 * It only widens `AppType`'s `E` parameter, which the typed client ignores — the
 * client reads the schema `S`, so this is invisible to the app.
 */
export type AppEnv = {
  Variables: RequestIdVariables;
};

import { timingSafeEqual } from 'node:crypto';
import type { MiddlewareHandler } from 'hono';
import { cors } from 'hono/cors';

import type { AppEnv } from './app-env';
import type { ErrorBody } from './errors';

/**
 * The header every first-party caller presents. Named `via` like every other
 * identifier the app ships (bundle id, keychain keys): the brand is Metyro, the
 * identifiers never moved.
 */
export const CLIENT_KEY_HEADER = 'x-via-client-key';

const encoder = new TextEncoder();

/**
 * Constant-time, so a refused key never tells its holder how much of it was
 * right. Length is compared first because `timingSafeEqual` throws on buffers of
 * different sizes — and a key's length was never the secret.
 */
function isSameSecret(presented: string, expected: string): boolean {
  const a = encoder.encode(presented);
  const b = encoder.encode(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

/**
 * `reduce` rather than `some`: every configured key is compared, so how long the
 * check takes says nothing about which one matched.
 */
export function presentsKnownKey(headers: Headers, keys: readonly string[]): boolean {
  const presented = headers.get(CLIENT_KEY_HEADER);
  if (!presented) return false;
  return keys.reduce((found, key) => isSameSecret(presented, key) || found, false);
}

export type ClientGateOptions = {
  /** Named in the boot log when the gate stays open. */
  readonly label: string;
  /** Secrets this caller presents. A list so a key rotates while old builds live. */
  readonly keys: readonly string[];
  /**
   * Browser origins that stand in for a key. Only meaningful for a caller that
   * runs in a browser: `Origin` is set by the browser and forgeable by anything
   * else, so it is a defence against other people's pages, never against curl.
   */
  readonly origins?: readonly string[];
  /** Paths answered without any credential — platform health probes. */
  readonly exempt?: readonly string[];
};

/**
 * Refuses everyone who cannot name themselves. Mounted above the routers so a
 * route added later is private by construction rather than by memory.
 *
 * Configuring nothing leaves the surface exactly as open as it was before this
 * middleware existed, which is what keeps `bun dev` and the test suite working
 * with an empty `.env`. A deployment closes itself by setting the variables, and
 * the boot log names every gate still standing open.
 */
export function createClientGate({
  label,
  keys,
  origins = [],
  exempt = [],
}: ClientGateOptions): MiddlewareHandler<AppEnv> {
  const exemptPaths = new Set(exempt);
  const allowedOrigins = new Set(origins);
  const open = keys.length === 0 && allowedOrigins.size === 0;

  if (open) {
    console.warn(
      `[api] the "${label}" surface accepts any caller: no client key and no allowed origin is configured.`
    );
  }

  return async function clientGate(c, next) {
    if (open || exemptPaths.has(c.req.path)) {
      await next();
      return;
    }

    const origin = c.req.header('origin');
    if ((origin && allowedOrigins.has(origin)) || presentsKnownKey(c.req.raw.headers, keys)) {
      await next();
      return;
    }

    const body: ErrorBody = {
      error: {
        code: 'unknown_client',
        message: 'This API only answers the Metyro app and the Metyro site.',
        requestId: c.get('requestId'),
      },
    };
    return c.json(body, 403);
  };
}

/**
 * CORS for the one browser that is allowed here. An empty allowlist keeps hono's
 * wildcard — same reasoning as the gate: an unconfigured environment behaves as
 * it did, a configured one is closed.
 */
export function clientCors(origins: readonly string[]): MiddlewareHandler<AppEnv> {
  if (origins.length === 0) return cors();

  const allowed = new Set(origins);
  return cors({
    origin: (origin) => (allowed.has(origin) ? origin : null),
    allowMethods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowHeaders: ['accept', 'authorization', 'content-type', CLIENT_KEY_HEADER],
    exposeHeaders: ['set-auth-token'],
    maxAge: 600,
  });
}

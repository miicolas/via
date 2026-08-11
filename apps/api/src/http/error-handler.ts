import type { ErrorHandler } from 'hono';
import { HTTPException } from 'hono/http-exception';

import type { AppEnv } from './app-env';
import type { ErrorBody } from './errors';

/**
 * Everything thrown below here lands in one envelope.
 *
 * Unhandled errors deliberately do not leak `error.message` — a drizzle or
 * PostGIS failure would put the SQL and the schema in a client-visible payload —
 * but they do carry the request id, so a user-reported failure is one grep away
 * in the logs.
 */
export const onError: ErrorHandler<AppEnv> = (error, c) => {
  const requestId = c.get('requestId');

  if (error instanceof HTTPException) {
    if (error.res) return error.res;

    const body: ErrorBody = {
      error: { code: 'bad_request', message: error.message, requestId },
    };

    return c.json(body, error.status);
  }

  console.error('[api] unhandled error', { requestId, error });

  const body: ErrorBody = {
    error: { code: 'internal_server_error', message: 'Internal Server Error', requestId },
  };

  return c.json(body, 500);
};

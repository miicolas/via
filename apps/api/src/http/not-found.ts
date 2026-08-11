import type { NotFoundHandler } from 'hono';

import type { AppEnv } from './app-env';
import type { ErrorBody } from './errors';

/**
 * Hono's default 404 is a bare `404 Not Found` text body. Echoing the method and
 * path instead turns "the app gets a 404" into an immediately actionable report,
 * which matters because the mobile client addresses routes by path string.
 */
export const notFound: NotFoundHandler<AppEnv> = (c) => {
  const body: ErrorBody = {
    error: {
      code: 'not_found',
      message: `No route for ${c.req.method} ${c.req.path}`,
      requestId: c.get('requestId'),
    },
  };

  return c.json(body, 404);
};

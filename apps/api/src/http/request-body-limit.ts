import { bodyLimit } from 'hono/body-limit';

import { errorBody } from './errors';

/** Maximum request body accepted by any public API surface. */
export const MAX_REQUEST_BODY_BYTES = 1_048_576;

/**
 * Enforce the edge limit before authentication, routing, or body parsing. Hono
 * handles both declared content lengths and chunked request streams.
 */
export const requestBodyLimit = bodyLimit({
  maxSize: MAX_REQUEST_BODY_BYTES,
  onError: (c) =>
    c.json(errorBody(c, 'payload_too_large', 'Request body exceeds 1 MiB.'), 413),
});

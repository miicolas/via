/**
 * The single envelope the API emits for anything not modelled per-route.
 *
 * Route-level outcomes ("this line id doesn't exist") stay as typed
 * `c.json({ error: '…' as const }, 404)` returns, because a caller should be
 * forced to handle them. This shape is for everything a caller can only log:
 * malformed requests and unhandled failures.
 */
export type ErrorBody = {
  error: {
    code: string;
    message: string;
    requestId?: string;
  };
};

/**
 * The one way to build that envelope.
 *
 * `requestId` is the whole point of the shape: it is what turns "the page said
 * it was unavailable" into a line in the logs. Spelled per mount, one of them
 * forgets it — so the mounts spell nothing and call this.
 */
export function errorBody(
  c: { get: (key: 'requestId') => string | undefined },
  code: string,
  message: string
): ErrorBody {
  const requestId = c.get('requestId');
  return {
    error: {
      code,
      message,
      ...(requestId === undefined ? {} : { requestId }),
    },
  };
}

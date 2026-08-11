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

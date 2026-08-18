/**
 * The route is authenticated, so only the device cache may reuse the payload.
 * 30 s stays under the 120 s Redis snapshot TTL — the shared cache upstream,
 * not this header, is what protects the PRIM quota.
 */
export const LINES_CACHE_CONTROL = 'private, max-age=30';

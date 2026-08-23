/**
 * Network payloads only change when a scheduled transit-reference import runs
 * — daily at most. A day of freshness plus a week of stale-while-revalidate
 * lets the HTTP cache absorb the repeat traffic the tiled `stationsInArea`
 * calls generate: panning back over a tile is a cache hit, not a request.
 */
export const NETWORK_CACHE_CONTROL = 'private, max-age=86400, stale-while-revalidate=604800';

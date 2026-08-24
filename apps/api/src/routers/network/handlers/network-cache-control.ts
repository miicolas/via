/**
 * `stationsInArea` also carries minute-scale Vélib' inventory. The API's own
 * shared snapshot absorbs upstream traffic; device HTTP caches may reuse a
 * tile briefly while still refreshing bike counts during a visible session.
 */
export const STATIONS_AREA_CACHE_CONTROL = 'private, max-age=30, stale-while-revalidate=120';

/** Rail geometry only changes after a reference-data import. */
export const RAIL_MAP_CACHE_CONTROL = 'private, max-age=86400, stale-while-revalidate=604800';

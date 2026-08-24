/**
 * Stations, lines and their badges only change at reference-data import, so a
 * tile stands for a day and panning back over it is a cache hit rather than a
 * request. Vélib' rides on its own route precisely so it cannot drag this down
 * to its own cadence — see `BIKE_STATIONS_CACHE_CONTROL`.
 */
export const STATIONS_AREA_CACHE_CONTROL = 'private, max-age=86400, stale-while-revalidate=604800';

/** Dock counts move by the minute; the API's shared snapshot is 55 s wide. */
export const BIKE_STATIONS_CACHE_CONTROL = 'private, max-age=30, stale-while-revalidate=120';

/** Rail geometry only changes after a reference-data import. */
export const RAIL_MAP_CACHE_CONTROL = 'private, max-age=86400, stale-while-revalidate=604800';

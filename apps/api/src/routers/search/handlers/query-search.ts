import { implementer } from '../../../orpc/implementer';
import { toStationResults } from '../mappers';
import { selectMatchingStations } from '../queries';

/**
 * `private`: the ranking depends on the caller's position, so a shared cache
 * must not serve one user's results to another. 30 s only absorbs a user
 * retyping the same query.
 */
const SEARCH_CACHE_CONTROL = 'private, max-age=30';

/** Stations fetched per query, before merging with addresses. */
const STATION_LIMIT = 5;

export const querySearch = implementer.search.query.handler(async ({ input, context }) => {
  const origin =
    input.latitude !== undefined && input.longitude !== undefined
      ? { latitude: input.latitude, longitude: input.longitude }
      : undefined;

  const stationRows = await selectMatchingStations(input.q, STATION_LIMIT, origin);

  context.resHeaders?.set('Cache-Control', SEARCH_CACHE_CONTROL);

  return {
    results: toStationResults(stationRows).slice(0, input.limit),
    sources: { ban: 'unavailable' as const },
  };
});

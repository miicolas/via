import { implementer } from '../../../orpc/implementer';
import { searchBan } from '../ban-client';
import { toAddressResults } from '../ban-mappers';
import { toStationResults } from '../mappers';
import { mergeSearchResults } from '../merge';
import { selectMatchingStations } from '../queries';

/**
 * `private`: the ranking depends on the caller's position, so a shared cache
 * must not serve one user's results to another. 30 s only absorbs a user
 * retyping the same query.
 */
const SEARCH_CACHE_CONTROL = 'private, max-age=30';

/** Per-source fetch sizes, before the merge truncates to `input.limit`. */
const STATION_LIMIT = 5;
const ADDRESS_LIMIT = 5;

export const querySearch = implementer.search.query.handler(
  async ({ input, context, signal }) => {
    const origin =
      input.latitude !== undefined && input.longitude !== undefined
        ? { latitude: input.latitude, longitude: input.longitude }
        : undefined;

    const [stationRows, banFeatures] = await Promise.all([
      selectMatchingStations(input.q, STATION_LIMIT, origin),
      searchBan(input.q, { limit: ADDRESS_LIMIT, origin, signal }),
    ]);

    context.resHeaders?.set('Cache-Control', SEARCH_CACHE_CONTROL);

    return {
      results: mergeSearchResults(
        toStationResults(stationRows),
        toAddressResults(banFeatures ?? []),
        { q: input.q, limit: input.limit, origin }
      ),
      sources: { ban: banFeatures === null ? ('unavailable' as const) : ('ok' as const) },
    };
  }
);

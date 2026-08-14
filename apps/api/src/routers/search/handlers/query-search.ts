import { implementer } from '../../../orpc/implementer';
import { searchPlaces } from '../search-places';

/**
 * `private`: the ranking depends on the caller's position, so a shared cache
 * must not serve one user's results to another. 30 s only absorbs a user
 * retyping the same query.
 */
const SEARCH_CACHE_CONTROL = 'private, max-age=30';

export const querySearch = implementer.search.query.handler(
  async ({ input, context, signal }) => {
    const origin =
      input.latitude !== undefined && input.longitude !== undefined
        ? { latitude: input.latitude, longitude: input.longitude }
        : undefined;

    const { results, banAvailable } = await searchPlaces(input.q, {
      limit: input.limit,
      origin,
      signal,
    });

    context.resHeaders?.set('Cache-Control', SEARCH_CACHE_CONTROL);

    return {
      results,
      sources: { ban: banAvailable ? ('ok' as const) : ('unavailable' as const) },
    };
  }
);

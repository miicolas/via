import { createFactory } from 'hono/factory';

import type { AppEnv } from '../../../http/app-env';
import { cacheControl } from '../../../middleware/cache-control';
import { toNetworkMap } from '../mappers';
import { selectMetroPatterns, selectMetroStationPositions } from '../queries';

const factory = createFactory<AppEnv>();

/**
 * `createHandlers` rather than a bare async function: it is what lets the handler
 * live in its own file without losing the `c.json()` return type, which is
 * exactly what `InferResponseType<…, 200>` reads in the app.
 */
export const getNetworkMapHandlers = factory.createHandlers(
  /**
   * The network is rebuilt by a GTFS import at most once a day, so five minutes
   * of cache with a one-hour stale window makes a cold app start instant without
   * ever pinning a wrong line shape for long.
   */
  cacheControl('public, max-age=300, stale-while-revalidate=3600'),
  async (c) => {
    // Independent queries — the station projection is the slow one, so don't
    // wait on it twice.
    const [patternRows, stationRows] = await Promise.all([
      selectMetroPatterns(),
      selectMetroStationPositions(),
    ]);

    return c.json(toNetworkMap(patternRows, stationRows));
  }
);

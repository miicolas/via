import { implementer } from '../../../orpc/implementer';
import { toNetworkMap } from '../mappers';
import { selectMetroPatterns, selectMetroStationPositions } from '../queries';

/**
 * The network is rebuilt by a GTFS import at most once a day, so five minutes of
 * cache with a one-hour stale window makes a cold app start instant without ever
 * pinning a wrong line shape for long.
 *
 * It matters more than it looks: the payload is ~890 kB, and because the contract
 * routes this as a real `GET`, the platform HTTP cache honours it — which an RPC
 * transport POSTing to a single endpoint would not.
 */
const NETWORK_MAP_CACHE_CONTROL = 'public, max-age=300, stale-while-revalidate=3600';

export const getNetworkMap = implementer.network.map.handler(async ({ context }) => {
  // Independent queries — the station projection is the slow one, so don't wait
  // on it twice.
  const [patternRows, stationRows] = await Promise.all([
    selectMetroPatterns(),
    selectMetroStationPositions(),
  ]);

  context.resHeaders?.set('Cache-Control', NETWORK_MAP_CACHE_CONTROL);

  return toNetworkMap(patternRows, stationRows);
});

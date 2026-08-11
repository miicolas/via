import { implementer } from '../../../orpc/implementer';
import { toNetworkMap } from '../mappers';
import { selectMetroPatterns, selectMetroStationPositions } from '../queries';

const NETWORK_MAP_CACHE_CONTROL = 'public, max-age=300, stale-while-revalidate=3600';

export const getNetworkMap = implementer.network.map.handler(async ({ context }) => {
  const [patternRows, stationRows] = await Promise.all([
    selectMetroPatterns(),
    selectMetroStationPositions(),
  ]);

  context.resHeaders?.set('Cache-Control', NETWORK_MAP_CACHE_CONTROL);

  return toNetworkMap(patternRows, stationRows);
});

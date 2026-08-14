import { implementer } from '../../../orpc/implementer';
import { selectDrawnPatterns, selectRailStationPositions } from '../queries';
import { toRailMap } from '../to-rail-map';
import { NETWORK_CACHE_CONTROL } from './network-cache-control';

export const getRailMap = implementer.network.railMap.handler(async ({ context }) => {
  const [patternRows, stationRows] = await Promise.all([
    selectDrawnPatterns(),
    selectRailStationPositions(),
  ]);

  context.resHeaders?.set('Cache-Control', NETWORK_CACHE_CONTROL);

  return toRailMap(patternRows, stationRows);
});

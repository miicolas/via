import { implementer } from '../../../orpc/implementer';
import { toNetworkMap } from '../mappers';
import {
  selectBusPatterns,
  selectDrawnPatterns,
  selectNetworkStationPositions,
} from '../queries';

const NETWORK_MAP_CACHE_CONTROL = 'public, max-age=300, stale-while-revalidate=3600';

export const getNetworkMap = implementer.network.map.handler(async ({ context }) => {
  const [drawnPatternRows, busPatternRows, stationRows] = await Promise.all([
    selectDrawnPatterns(),
    selectBusPatterns(),
    selectNetworkStationPositions(),
  ]);

  context.resHeaders?.set('Cache-Control', NETWORK_MAP_CACHE_CONTROL);

  return toNetworkMap([...drawnPatternRows, ...busPatternRows], stationRows);
});

import { implementer } from '../../../orpc/implementer';
import { redis } from '../../../redis';
import { transitNetworkCacheVersion } from '../../departures/network-version';
import { selectDrawnPatterns, selectRailStationPositions } from '../queries';
import { toRailMap } from '../to-rail-map';
import { NETWORK_CACHE_CONTROL } from './network-cache-control';

type RailMap = ReturnType<typeof toRailMap>;

let memo: { version: string; value: RailMap } | undefined;

async function railMap(version: string): Promise<RailMap> {
  if (memo?.version === version) return memo.value;

  const [patternRows, stationRows] = await Promise.all([
    selectDrawnPatterns(),
    selectRailStationPositions(),
  ]);
  const value = toRailMap(patternRows, stationRows);

  memo = { version, value };
  return value;
}

export const getRailMap = implementer.network.railMap.handler(async ({ context }) => {
  const version = await transitNetworkCacheVersion(redis);
  const value = await railMap(version);

  context.resHeaders?.set('Cache-Control', NETWORK_CACHE_CONTROL);

  return value;
});

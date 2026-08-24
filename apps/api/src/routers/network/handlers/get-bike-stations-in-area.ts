import { implementer } from '../../../orpc/implementer';
import { selectBikeStationsInArea } from '../../velib/select';
import { getVelibSnapshot } from '../../velib/snapshot';
import { BIKE_STATIONS_CACHE_CONTROL } from './network-cache-control';

export const getBikeStationsInArea = implementer.network.bikeStationsInArea.handler(
  async ({ input, context }) => {
    const velib = await getVelibSnapshot();
    context.resHeaders?.set('Cache-Control', BIKE_STATIONS_CACHE_CONTROL);

    return {
      bikeStations: selectBikeStationsInArea(velib.stations, input),
      sources: { velib: velib.sourceAvailable ? ('ok' as const) : ('unavailable' as const) },
    };
  }
);

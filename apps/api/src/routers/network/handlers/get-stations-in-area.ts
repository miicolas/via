import { implementer } from '../../../orpc/implementer';
import { selectStationsInArea } from '../queries';
import { toStationsInArea } from '../to-stations-in-area';
import { getVelibSnapshot } from '../../velib/snapshot';
import { selectBikeStationsInArea } from '../../velib/select';
import { STATIONS_AREA_CACHE_CONTROL } from './network-cache-control';

export const getStationsInArea = implementer.network.stationsInArea.handler(
  async ({ input, context }) => {
    const [rows, velib] = await Promise.all([
      selectStationsInArea(input),
      getVelibSnapshot(),
    ]);

    context.resHeaders?.set('Cache-Control', STATIONS_AREA_CACHE_CONTROL);

    return toStationsInArea(
      rows,
      selectBikeStationsInArea(velib.stations, input),
      velib.sourceAvailable
    );
  }
);

import { implementer } from '../../../orpc/implementer';
import { selectStationHourProfiles } from '../queries';
import { toStationCrowding } from '../to-station-crowding';
import { STATION_CROWDING_CACHE_CONTROL } from './network-cache-control';

// Unlike `stationPeaks`, a db failure surfaces as an error here: this endpoint
// carries nothing else, so the client can simply hide the section, whereas an
// empty response is the legitimate "bus stop, no profile" answer.
export const getStationCrowding = implementer.network.stationCrowding.handler(
  async ({ input, context }) => {
    const rows = await selectStationHourProfiles(input.stationId);
    context.resHeaders?.set('Cache-Control', STATION_CROWDING_CACHE_CONTROL);
    return toStationCrowding(rows);
  }
);

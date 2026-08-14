import { getRailMap } from './handlers/get-rail-map';
import { getStationsInArea } from './handlers/get-stations-in-area';

export const networkRouter = {
  railMap: getRailMap,
  stationsInArea: getStationsInArea,
};

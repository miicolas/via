import { getBikeStationsInArea } from "./handlers/get-bike-stations-in-area";
import { getRailMap } from "./handlers/get-rail-map";
import { getStationCrowding } from "./handlers/get-station-crowding";
import { getStationsInArea } from "./handlers/get-stations-in-area";
import { getSharedMobilityInArea } from "./handlers/get-shared-mobility-in-area";

export const networkRouter = {
  railMap: getRailMap,
  stationsInArea: getStationsInArea,
  bikeStationsInArea: getBikeStationsInArea,
  sharedMobilityInArea: getSharedMobilityInArea,
  stationCrowding: getStationCrowding,
};

import { getStationDepartures } from './handlers/get-station-departures';

export const departuresRouter = {
  forStation: getStationDepartures,
};

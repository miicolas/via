import * as z from 'zod';

import {
  bikeStationAvailabilitySchema,
  bikeStationSchema,
  bikeStationsInAreaSchema,
  crowdingHourSchema,
  peakLevelSchema,
  networkRouteSchema,
  networkSegmentSchema,
  networkStationSchema,
  railMapSchema,
  stationCrowdingInputSchema,
  stationCrowdingSchema,
  stationToiletsSchema,
  stationsInAreaInputSchema,
  stationsInAreaSchema,
} from './schema';

export type BikeStationAvailability = z.infer<typeof bikeStationAvailabilitySchema>;
export type BikeStation = z.infer<typeof bikeStationSchema>;
export type BikeStationsInArea = z.infer<typeof bikeStationsInAreaSchema>;
export type NetworkSegment = z.infer<typeof networkSegmentSchema>;
export type NetworkRoute = z.infer<typeof networkRouteSchema>;
export type NetworkStation = z.infer<typeof networkStationSchema>;
export type StationToilets = z.infer<typeof stationToiletsSchema>;
export type RailMap = z.infer<typeof railMapSchema>;
export type StationsInAreaInput = z.infer<typeof stationsInAreaInputSchema>;
export type StationsInArea = z.infer<typeof stationsInAreaSchema>;
export type PeakLevel = z.infer<typeof peakLevelSchema>;
export type CrowdingHour = z.infer<typeof crowdingHourSchema>;
export type StationCrowdingInput = z.infer<typeof stationCrowdingInputSchema>;
export type StationCrowding = z.infer<typeof stationCrowdingSchema>;

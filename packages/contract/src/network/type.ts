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
  stationFountainsSchema,
  stationToiletsSchema,
  stationsInAreaInputSchema,
  stationsInAreaSchema,
  sharedMobilityInAreaSchema,
  sharedMobilityItemSchema,
  sharedMobilityModeSchema,
  sharedMobilityProviderSchema,
  sharedMobilitySourceStatusSchema,
  sharedMobilityStationSchema,
  sharedMobilityRestrictionSchema,
  sharedMobilityVehicleSchema,
} from './schema';

export type BikeStationAvailability = z.infer<typeof bikeStationAvailabilitySchema>;
export type BikeStation = z.infer<typeof bikeStationSchema>;
export type BikeStationsInArea = z.infer<typeof bikeStationsInAreaSchema>;
export type NetworkSegment = z.infer<typeof networkSegmentSchema>;
export type NetworkRoute = z.infer<typeof networkRouteSchema>;
export type NetworkStation = z.infer<typeof networkStationSchema>;
export type StationFountains = z.infer<typeof stationFountainsSchema>;
export type StationToilets = z.infer<typeof stationToiletsSchema>;
export type RailMap = z.infer<typeof railMapSchema>;
export type StationsInAreaInput = z.infer<typeof stationsInAreaInputSchema>;
export type StationsInArea = z.infer<typeof stationsInAreaSchema>;
export type PeakLevel = z.infer<typeof peakLevelSchema>;
export type CrowdingHour = z.infer<typeof crowdingHourSchema>;
export type StationCrowdingInput = z.infer<typeof stationCrowdingInputSchema>;
export type StationCrowding = z.infer<typeof stationCrowdingSchema>;
export type SharedMobilityProvider = z.infer<typeof sharedMobilityProviderSchema>;
export type SharedMobilityMode = z.infer<typeof sharedMobilityModeSchema>;
export type SharedMobilitySourceStatus = z.infer<typeof sharedMobilitySourceStatusSchema>;
export type SharedMobilityVehicle = z.infer<typeof sharedMobilityVehicleSchema>;
export type SharedMobilityRestriction = z.infer<typeof sharedMobilityRestrictionSchema>;
export type SharedMobilityStation = z.infer<typeof sharedMobilityStationSchema>;
export type SharedMobilityItem = z.infer<typeof sharedMobilityItemSchema>;
export type SharedMobilityInArea = z.infer<typeof sharedMobilityInAreaSchema>;

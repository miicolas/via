import * as z from 'zod';

import {
  networkRouteSchema,
  networkSegmentSchema,
  networkStationSchema,
  railMapSchema,
  stationToiletsSchema,
  stationsInAreaInputSchema,
  stationsInAreaSchema,
} from './schema';

export type NetworkSegment = z.infer<typeof networkSegmentSchema>;
export type NetworkRoute = z.infer<typeof networkRouteSchema>;
export type NetworkStation = z.infer<typeof networkStationSchema>;
export type StationToilets = z.infer<typeof stationToiletsSchema>;
export type RailMap = z.infer<typeof railMapSchema>;
export type StationsInAreaInput = z.infer<typeof stationsInAreaInputSchema>;
export type StationsInArea = z.infer<typeof stationsInAreaSchema>;

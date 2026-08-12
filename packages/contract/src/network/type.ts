import * as z from 'zod';

import {
  networkMapSchema,
  networkModeSchema,
  networkRouteSchema,
  networkSegmentSchema,
  networkStationSchema,
} from './schema';

export type NetworkSegment = z.infer<typeof networkSegmentSchema>;
export type NetworkMode = z.infer<typeof networkModeSchema>;
export type NetworkRoute = z.infer<typeof networkRouteSchema>;
export type NetworkStation = z.infer<typeof networkStationSchema>;
export type NetworkMap = z.infer<typeof networkMapSchema>;

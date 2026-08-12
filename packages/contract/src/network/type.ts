import * as z from 'zod';

import {
  networkMapSchema,
  networkRouteSchema,
  networkSegmentSchema,
  networkStationSchema,
} from './schema';

export type NetworkSegment = z.infer<typeof networkSegmentSchema>;
export type NetworkRoute = z.infer<typeof networkRouteSchema>;
export type NetworkStation = z.infer<typeof networkStationSchema>;
export type NetworkMap = z.infer<typeof networkMapSchema>;

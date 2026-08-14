import * as z from 'zod';

import { coordinateSchema, networkModeSchema, routeBadgeSchema } from './schema';

export type Coordinate = z.infer<typeof coordinateSchema>;
export type NetworkMode = z.infer<typeof networkModeSchema>;
export type RouteBadge = z.infer<typeof routeBadgeSchema>;

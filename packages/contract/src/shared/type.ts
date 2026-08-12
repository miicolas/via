import * as z from 'zod';

import { coordinateSchema } from './schema';

export type Coordinate = z.infer<typeof coordinateSchema>;

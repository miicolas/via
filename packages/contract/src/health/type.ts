import * as z from 'zod';

import { healthSchema } from './schema';

export type Health = z.infer<typeof healthSchema>;

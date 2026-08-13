import * as z from 'zod';

import {
  journeyDestinationSchema,
  journeyInputSchema,
  journeySchema,
  journeysResponseSchema,
  journeySectionSchema,
  journeyStopSchema,
} from './schema';

export type JourneyDestination = z.infer<typeof journeyDestinationSchema>;
export type JourneyInput = z.infer<typeof journeyInputSchema>;
export type Journey = z.infer<typeof journeySchema>;
export type JourneySection = z.infer<typeof journeySectionSchema>;
export type JourneyStop = z.infer<typeof journeyStopSchema>;
export type JourneysResponse = z.infer<typeof journeysResponseSchema>;

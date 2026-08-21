import * as z from 'zod';

import {
  naturalJourneyInputSchema,
  naturalJourneyInterpretationSchema,
  naturalJourneyResultSchema,
} from './schema';

export type NaturalJourneyInput = z.infer<typeof naturalJourneyInputSchema>;
export type NaturalJourneyInterpretation = z.infer<typeof naturalJourneyInterpretationSchema>;
export type NaturalJourneyResult = z.infer<typeof naturalJourneyResultSchema>;

import * as z from 'zod';

import {
  naturalJourneyInputSchema,
  naturalJourneyInterpretationSchema,
  naturalJourneyModelInterpretationSchema,
  naturalJourneyResultSchema,
} from './schema';

export type NaturalJourneyInput = z.infer<typeof naturalJourneyInputSchema>;
export type NaturalJourneyInterpretation = z.infer<typeof naturalJourneyInterpretationSchema>;
export type NaturalJourneyModelInterpretation = z.infer<
  typeof naturalJourneyModelInterpretationSchema
>;
export type NaturalJourneyResult = z.infer<typeof naturalJourneyResultSchema>;

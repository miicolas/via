import * as z from 'zod';

import {
  naturalJourneyDraftSchema,
  naturalJourneyInputSchema,
  naturalJourneyResponseSchema,
  routeIntentSchema,
} from './schema';

export type RouteIntent = z.infer<typeof routeIntentSchema>;
export type NaturalJourneyDraft = z.infer<typeof naturalJourneyDraftSchema>;
export type NaturalJourneyInput = z.infer<typeof naturalJourneyInputSchema>;
export type NaturalJourneyResponse = z.infer<typeof naturalJourneyResponseSchema>;

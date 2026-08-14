import * as z from 'zod';

import {
  journeyDatetimeRepresentsSchema,
  journeyDestinationSchema,
  journeyModeSchema,
  journeysResponseSchema,
} from '../journeys/schema';
import { searchResultSchema } from '../search/schema';
import { coordinateSchema } from '../shared/schema';

export const routeIntentSchema = z.object({
  scope: z.enum(['journey', 'unsupported']),
  // Plain union, not discriminatedUnion: this schema is sent to OpenAI as a
  // response format, and its JSON-schema conversion must emit `anyOf` —
  // `oneOf` (what discriminatedUnion produces) is rejected with a 400.
  origin: z.union([
    z.object({ kind: z.literal('current_location') }),
    z.object({ kind: z.literal('place'), query: z.string().trim().min(1).max(160) }),
  ]),
  destinationQuery: z.string().trim().min(1).max(160).nullable(),
  requestedAt: z.iso.datetime({ offset: true }).nullable(),
  datetimeRepresents: z.enum(['departure', 'arrival', 'ambiguous']),
  requiredModes: z.array(journeyModeSchema).max(3),
  excludedModes: z.array(journeyModeSchema).max(3),
  preferredModes: z.array(journeyModeSchema).max(3),
});

export const naturalJourneyDraftSchema = z.object({
  intent: routeIntentSchema,
  origin: searchResultSchema.optional(),
  destination: searchResultSchema.optional(),
});

export const naturalJourneyInputSchema = z.discriminatedUnion('action', [
  z.object({
    action: z.literal('submit'),
    query: z.string().trim().min(1).max(200),
    currentLocation: coordinateSchema.optional(),
  }),
  z.object({
    action: z.literal('resolve'),
    draft: naturalJourneyDraftSchema,
    currentLocation: coordinateSchema.optional(),
    origin: searchResultSchema.optional(),
    destination: searchResultSchema.optional(),
    datetimeRepresents: journeyDatetimeRepresentsSchema.optional(),
  }),
]);

export const naturalJourneyClarificationFieldSchema = z.object({
  target: z.enum(['origin', 'destination', 'time']),
  question: z.string(),
  candidates: z.array(searchResultSchema).default([]),
});

const naturalJourneyInterpretationSchema = z.object({
  originLabel: z.string(),
  destination: journeyDestinationSchema,
  destinationResult: searchResultSchema,
  requestedAt: z.iso.datetime({ offset: true }),
  datetimeRepresents: journeyDatetimeRepresentsSchema,
  requiredModes: z.array(journeyModeSchema),
  excludedModes: z.array(journeyModeSchema),
  preferredModes: z.array(journeyModeSchema),
});

export const naturalJourneyResponseSchema = z.discriminatedUnion('status', [
  z.object({
    status: z.literal('ready'),
    answer: z.string(),
    answerSource: z.enum(['ai', 'deterministic']),
    preferenceNotice: z.string().optional(),
    interpretation: naturalJourneyInterpretationSchema,
    journeys: journeysResponseSchema,
  }),
  z.object({
    status: z.literal('needs_clarification'),
    draft: naturalJourneyDraftSchema,
    fields: z.array(naturalJourneyClarificationFieldSchema).min(1),
  }),
  z.object({
    status: z.literal('unsupported'),
    message: z.string(),
    examples: z.array(z.string()).length(2),
  }),
  z.object({
    status: z.literal('unavailable'),
    reason: z.enum(['ai', 'geocoder', 'journey', 'date_out_of_range', 'location']),
    message: z.string(),
  }),
  z.object({
    status: z.literal('rate_limited'),
    message: z.string(),
  }),
]);

import * as z from 'zod';

import {
  journeyDatetimeRepresentsSchema,
  journeyDestinationSchema,
  journeyModeSchema,
  journeyTimeAnchorSchema,
} from '../journeys/schema';
import { searchResultSchema } from '../search/schema';

export const naturalJourneyPlaceReferenceSchema = z.object({
  kind: z.enum(['current_location', 'query', 'saved', 'context_reference']),
  /** Query text, opaque saved-place id, or a bounded conversational reference. */
  value: z.string().max(160),
  /** Exact fragment copied from the user turn. */
  evidence: z.string().max(160),
});

export const naturalJourneySavedPlaceAliasSchema = z.object({
  id: z.string().min(1).max(128),
  label: z.string().min(1).max(80),
  kind: z.enum(['home', 'work', 'custom']),
});

export const naturalJourneyAnchorsSchema = z.object({
  origin: naturalJourneyPlaceReferenceSchema.optional(),
  destination: naturalJourneyPlaceReferenceSchema.optional(),
});

const naturalDateReferenceSchema = z.enum([
  'implicit_today',
  'today',
  'tomorrow',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
  'calendar_date',
  'relative',
]);

const naturalTimePrecisionSchema = z.enum([
  'unspecified',
  'exact',
  'morning',
  'afternoon',
  'evening',
]);

export const naturalJourneyTimeConstraintSchema = z.object({
  reference: naturalDateReferenceSchema,
  year: z.number().int().min(2000).max(2100),
  yearWasExplicit: z.boolean(),
  month: z.number().int().min(1).max(12),
  day: z.number().int().min(1).max(31),
  timePrecision: naturalTimePrecisionSchema,
  hour: z.number().int().min(0).max(23),
  minute: z.number().int().min(0).max(59),
  relativeAmount: z.number().int().min(0).max(10080),
  relativeUnit: z.enum(['minute', 'hour', 'day']),
  meaning: z.enum(['departure', 'arrival', 'ambiguous']),
  evidence: z.string().max(160),
});

export const naturalJourneyModelInterpretationSchema = z.object({
  scope: z.enum(['journey', 'unsupported']),
  origin: naturalJourneyPlaceReferenceSchema.optional(),
  destination: naturalJourneyPlaceReferenceSchema.optional(),
  originWasExplicit: z.boolean(),
  lastServiceOfDay: z.boolean(),
  timeConstraint: naturalJourneyTimeConstraintSchema,
  alternateTimeConstraint: naturalJourneyTimeConstraintSchema.optional(),
  requiredModes: z.array(journeyModeSchema).max(3),
  excludedModes: z.array(journeyModeSchema).max(3),
  preferredModes: z.array(journeyModeSchema).max(3),
  unsupportedConstraints: z.array(z.string().min(1).max(160)).max(3),
  /** Significant fragment the model could not account for; empty when fully covered. */
  unexplainedText: z.string().max(200),
});

/**
 * Interpretation-only fallback. Coordinates, addresses and journey results are
 * intentionally absent: the iPhone resolves personal places and runs Via's
 * shared place/journey modules after validating this patch.
 */
export const naturalJourneyInputSchema = z.object({
  query: z.string().trim().min(1).max(500),
  locale: z.enum(['fr-FR', 'en']),
  requestedAt: z.iso.datetime({ offset: true }),
  hasCurrentLocation: z.boolean(),
  anchors: naturalJourneyAnchorsSchema,
  savedPlaces: z.array(naturalJourneySavedPlaceAliasSchema).max(22),
});

export const naturalJourneyResultSchema = z.discriminatedUnion('outcome', [
  z.object({
    outcome: z.literal('interpreted'),
    interpretation: naturalJourneyModelInterpretationSchema,
  }),
  z.object({
    outcome: z.literal('unavailable'),
    message: z.string(),
  }),
]);

// Retained only for the legacy rollback implementation while rollout is in
// progress. The nominal server path no longer returns these resolved values.
export const naturalJourneyInterpretationSchema = z.object({
  originLabel: z.string(),
  origin: searchResultSchema.optional(),
  destination: journeyDestinationSchema,
  destinationResult: searchResultSchema,
  requestedAt: z.iso.datetime({ offset: true }),
  datetimeRepresents: journeyDatetimeRepresentsSchema,
  timeAnchor: journeyTimeAnchorSchema.optional(),
  requiredModes: z.array(journeyModeSchema),
  excludedModes: z.array(journeyModeSchema),
  preferredModes: z.array(journeyModeSchema),
});

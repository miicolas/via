import * as z from 'zod';

import { accessibilityConditionSchema } from '../shared/schema';

export const reportCategorySchema = z.enum([
  'pickpocket',
  'crowding',
  'restroomsClosed',
  'ticketMachinesUnavailable',
  'wheelchairAccessUnavailable',
  'elevatorsUnavailable',
  'escalatorUnavailable',
  'validatorsUnavailable',
  'entranceOrExitClosed',
  'stopRelocated',
  'stopNotServed',
  'passengerInformationUnavailable',
  'passageObstructed',
]);

export const crowdingLevelSchema = z.enum(['low', 'moderate', 'high', 'saturated']);
/** The scale, least to most crowded. Every reader orders levels through this. */
export const CROWDING_LEVELS = crowdingLevelSchema.options;
export function crowdingSeverity(level: (typeof CROWDING_LEVELS)[number]) {
  return CROWDING_LEVELS.indexOf(level);
}
export const reportValueSchema = z.enum([
  'occurrence',
  'resolved',
  'low',
  'moderate',
  'high',
  'saturated',
]);
export const reportScopeKindSchema = z.enum(['station', 'line', 'vehicle']);

export const reportSubmissionInputSchema = z.object({
  id: z.uuid(),
  stationId: z.string().min(1).max(300),
  category: reportCategorySchema,
  value: reportValueSchema,
  lineId: z.string().min(1).max(300).optional(),
  journeyId: z.string().min(1).max(500).optional(),
  vehicleId: z.string().min(1).max(500).optional(),
}).superRefine((input, context) => {
  const isCrowdingLevel = crowdingLevelSchema.safeParse(input.value).success;
  if (input.category === 'crowding' && !isCrowdingLevel) {
    context.addIssue({ code: 'custom', path: ['value'], message: 'Un niveau d’affluence est requis.' });
  }
  if (input.category !== 'crowding' && isCrowdingLevel) {
    context.addIssue({ code: 'custom', path: ['value'], message: 'Ce niveau est réservé à l’affluence.' });
  }
  if (input.category === 'pickpocket' && input.value === 'resolved') {
    context.addIssue({ code: 'custom', path: ['value'], message: 'Un signalement de pickpocket expire automatiquement.' });
  }
});

export const stationStatusInputSchema = z.object({
  stationId: z.string().min(1).max(300),
  lineId: z.string().min(1).max(300).optional(),
  vehicleId: z.string().min(1).max(500).optional(),
});

const automaticAccessibilitySchema = z.object({
  state: z.literal('available'),
  source: z.literal('automatic'),
  condition: accessibilityConditionSchema,
  label: z.string(),
});

const reportedAccessibilitySchema = z.object({
  state: z.literal('unavailable'),
  source: z.literal('reported'),
  label: z.string(),
  reporterCount: z.number().int().positive(),
  observedAt: z.iso.datetime({ offset: true }),
  expiresAt: z.iso.datetime({ offset: true }),
  confidence: z.enum(['observed', 'confirmed']),
});

export const effectiveAccessibilitySchema = z.union([
  automaticAccessibilitySchema,
  reportedAccessibilitySchema,
]);

export const effectiveCrowdingSchema = z.object({
  level: crowdingLevelSchema,
  source: z.enum(['automatic', 'reported']),
  label: z.string(),
  reporterCount: z.number().int().positive().optional(),
  observedAt: z.iso.datetime({ offset: true }).optional(),
  expiresAt: z.iso.datetime({ offset: true }).optional(),
});

export const effectiveIncidentSchema = z.object({
  category: reportCategorySchema.exclude(['crowding']),
  scopeKind: reportScopeKindSchema,
  scopeId: z.string(),
  state: z.enum(['active', 'recovered']),
  label: z.string(),
  reporterCount: z.number().int().positive(),
  observedAt: z.iso.datetime({ offset: true }),
  expiresAt: z.iso.datetime({ offset: true }),
});

export const stationStatusSchema = z.object({
  stationId: z.string(),
  generatedAt: z.iso.datetime({ offset: true }),
  accessibility: effectiveAccessibilitySchema.optional(),
  crowding: effectiveCrowdingSchema.optional(),
  incidents: z.array(effectiveIncidentSchema),
  wheelchairRouteExcluded: z.boolean(),
});

export const reportSubmissionResponseSchema = stationStatusSchema;

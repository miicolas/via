import * as z from 'zod';

import {
  crowdingLevelSchema,
  effectiveAccessibilitySchema,
  effectiveCrowdingSchema,
  effectiveIncidentSchema,
  reportCategorySchema,
  reportScopeKindSchema,
  reportSubmissionInputSchema,
  reportValueSchema,
  stationStatusSchema,
} from './schema';

export type ReportCategory = z.infer<typeof reportCategorySchema>;
export type ReportValue = z.infer<typeof reportValueSchema>;
export type ReportScopeKind = z.infer<typeof reportScopeKindSchema>;
export type CrowdingLevel = z.infer<typeof crowdingLevelSchema>;
export type ReportSubmissionInput = z.infer<typeof reportSubmissionInputSchema>;
export type EffectiveAccessibility = z.infer<typeof effectiveAccessibilitySchema>;
export type EffectiveCrowding = z.infer<typeof effectiveCrowdingSchema>;
export type EffectiveIncident = z.infer<typeof effectiveIncidentSchema>;
export type StationStatus = z.infer<typeof stationStatusSchema>;

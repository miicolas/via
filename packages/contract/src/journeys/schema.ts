import * as z from 'zod';

import { coordinateSchema, networkModeSchema } from '../shared/schema';

export const journeyModeSchema = networkModeSchema;
export const journeyDatetimeRepresentsSchema = z.enum(['departure', 'arrival']);

export const journeyDestinationSchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('station'),
    id: z.string().min(1),
    name: z.string().min(1),
    coordinate: coordinateSchema,
  }),
  z.object({
    kind: z.literal('address'),
    id: z.string().min(1),
    name: z.string().min(1),
    context: z.string().optional(),
    coordinate: coordinateSchema,
  }),
]);

export const journeyInputSchema = z.object({
  origin: coordinateSchema,
  destination: journeyDestinationSchema,
  limit: z.int().min(1).max(6).default(4),
  /** Omitted by the classic flow, which keeps its current "leave now" behavior. */
  requestedAt: z.iso.datetime({ offset: true }).optional(),
  datetimeRepresents: journeyDatetimeRepresentsSchema.optional(),
  requiredModes: z.array(journeyModeSchema).max(3).optional(),
  excludedModes: z.array(journeyModeSchema).max(3).optional(),
  preferredModes: z.array(journeyModeSchema).max(3).optional(),
});

export const journeyQualifierSchema = z.enum([
  'recommended',
  'rapid',
  'less-walking',
  'comfort',
  'walking',
]);

export const journeyStatusSchema = z.enum(['normal', 'disrupted', 'theoretical']);
export const journeySectionTypeSchema = z.enum(['walk', 'wait', 'transfer', 'transit']);

export const journeyStopSchema = z.object({
  id: z.string(),
  name: z.string(),
  coordinate: coordinateSchema,
  arrivalAt: z.iso.datetime({ offset: true }).optional(),
  departureAt: z.iso.datetime({ offset: true }).optional(),
});

export const journeyRouteSchema = z.object({
  id: z.string(),
  shortName: z.string(),
  longName: z.string(),
  mode: journeyModeSchema,
  color: z.string(),
  textColor: z.string(),
});

export const journeySectionSchema = z.object({
  type: journeySectionTypeSchema,
  durationSeconds: z.number().int().nonnegative(),
  from: z.object({ name: z.string(), coordinate: coordinateSchema }),
  to: z.object({ name: z.string(), coordinate: coordinateSchema }),
  departureAt: z.iso.datetime({ offset: true }).optional(),
  arrivalAt: z.iso.datetime({ offset: true }).optional(),
  geometry: z.array(coordinateSchema),
  route: journeyRouteSchema.optional(),
  direction: z.string().optional(),
  platform: z.string().optional(),
  stops: z.array(journeyStopSchema).default([]),
});

export const journeySchema = z.object({
  id: z.string(),
  qualifier: journeyQualifierSchema,
  durationSeconds: z.number().int().nonnegative(),
  walkingDurationSeconds: z.number().int().nonnegative(),
  transferCount: z.number().int().nonnegative(),
  departureAt: z.iso.datetime({ offset: true }),
  arrivalAt: z.iso.datetime({ offset: true }),
  status: journeyStatusSchema,
  warnings: z.array(z.string()),
  sections: z.array(journeySectionSchema).min(1),
});

export const journeysResponseSchema = z.object({
  status: z.enum(['ready', 'no-route', 'unavailable']),
  source: z.enum(['idfm-realtime', 'gtfs-theoretical']).optional(),
  generatedAt: z.iso.datetime({ offset: true }),
  journeys: z.array(journeySchema),
});

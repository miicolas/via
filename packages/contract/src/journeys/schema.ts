import * as z from 'zod';

import {
  accessibilityConditionSchema,
  coordinateParamSchema,
  coordinateSchema,
  networkModeSchema,
  queryBooleanSchema,
} from '../shared/schema';

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

/**
 * GET /journeys carries its input in the query string, and deepObject
 * serialization only supports one level of primitives — swift-openapi-runtime
 * refuses nested objects before the request is even sent. So the wire shape
 * flattens `coordinate` into `latitude`/`longitude` and parses back into
 * {@link journeyDestinationSchema} server-side; handlers never see the flat form.
 * Query values arrive as strings, hence the explicit coercion.
 */
export const journeyDestinationWireSchema = z.discriminatedUnion('kind', [
  z.object({
    kind: z.literal('station'),
    id: z.string().min(1),
    name: z.string().min(1),
    latitude: z.coerce.number(),
    longitude: z.coerce.number(),
  }),
  z.object({
    kind: z.literal('address'),
    id: z.string().min(1),
    name: z.string().min(1),
    context: z.string().optional(),
    latitude: z.coerce.number(),
    longitude: z.coerce.number(),
  }),
]);

const journeyDestinationParamSchema = journeyDestinationWireSchema
  .transform(({ latitude, longitude, ...place }) => ({
    ...place,
    coordinate: { latitude, longitude },
  }))
  .pipe(journeyDestinationSchema);

/** Same constraint as the destination: arrays don't survive deepObject either, so modes ride as CSV. */
const journeyModeListParamSchema = z
  .string()
  .transform((raw) => raw.split(',').filter((mode) => mode.length > 0))
  .pipe(z.array(journeyModeSchema).max(3));

export const journeyInputSchema = z.object({
  origin: coordinateParamSchema,
  destination: journeyDestinationParamSchema,
  limit: z.int().min(1).max(6).default(4),
  /** Omitted by the classic flow, which keeps its current "leave now" behavior. */
  requestedAt: z.iso.datetime({ offset: true }).optional(),
  datetimeRepresents: journeyDatetimeRepresentsSchema.optional(),
  requiredModes: journeyModeListParamSchema.optional(),
  excludedModes: journeyModeListParamSchema.optional(),
  preferredModes: journeyModeListParamSchema.optional(),
  /** Require every used boarding, alighting, and transfer station to be declared PMR-accessible. */
  requiresAccessibleStations: queryBooleanSchema.optional(),
  /** The user explicitly selected this station as origin; preserve that choice when filtering. */
  originStationId: z.string().min(1).optional(),
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
  accessibility: z
    .object({
      condition: accessibilityConditionSchema,
      label: z.string(),
    })
    .optional(),
  sections: z.array(journeySectionSchema).min(1),
});

export const journeysResponseSchema = z.object({
  status: z.enum(['ready', 'no-route', 'unavailable']),
  source: z.enum(['idfm-realtime', 'gtfs-theoretical']).optional(),
  generatedAt: z.iso.datetime({ offset: true }),
  reason: z.enum(['no-accessible-route', 'accessibility-data-unavailable']).optional(),
  journeys: z.array(journeySchema),
});

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

export const boardingPositionZoneSchema = z.enum(['front', 'middle', 'rear']);
export const boardingPositionEquipmentSchema = z.enum(['escalator', 'lift', 'stairs']);

/**
 * Where to stand on the platform before the train arrives, so its doors open in
 * front of the exit or the connection this traveller needs next.
 *
 * `car` counts from the head of the train in its direction of travel, so the
 * advice only holds for the direction of the section carrying it. `carCount` is
 * the line's nominal train length: a short trainset makes the number optimistic,
 * which is why `zone` ships alongside it and is what the app leads with.
 *
 * Only the RATP metro and RER A/B publish this, and only the realtime planner
 * resolves the quay it is keyed by — absent everywhere else.
 */
export const boardingPositionSchema = z.object({
  car: z.int().min(1),
  carCount: z.int().min(1),
  zone: boardingPositionZoneSchema,
  /** What the advice optimizes for: leaving the network, or catching the next line. */
  reason: z.enum(['exit', 'transfer']),
  equipment: boardingPositionEquipmentSchema.optional(),
});

/** The station exit nearest the journey's destination, with the number on its signage. */
export const journeyExitSchema = z.object({
  id: z.string(),
  name: z.string(),
  number: z.int().optional(),
  coordinate: coordinateSchema,
  /** Straight line from the exit to the destination — an order of magnitude, not a route. */
  walkingMeters: z.int().nonnegative().optional(),
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
  /** Followed when boarding this section; computed from where it ends. */
  boardingPosition: boardingPositionSchema.optional(),
  /** Only ever on the last transit section — where to leave the network. */
  exit: journeyExitSchema.optional(),
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

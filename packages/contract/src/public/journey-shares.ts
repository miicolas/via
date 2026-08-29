import * as z from "zod";

export const publicCoordinateSchema = z.strictObject({
  latitude: z.number(),
  longitude: z.number(),
});

export const publicJourneyRouteSchema = z.strictObject({
  shortName: z.string(),
  longName: z.string(),
  color: z.string(),
  textColor: z.string(),
});

const publicJourneyStopSchema = z.strictObject({
  name: z.string(),
  arrivalAt: z.iso.datetime({ offset: true }).optional(),
  departureAt: z.iso.datetime({ offset: true }).optional(),
});

export const publicJourneySectionSchema = z.strictObject({
  id: z.string().optional(),
  type: z.enum(["walk", "bike", "wait", "transfer", "transit"]),
  durationSeconds: z.number().int().nonnegative(),
  from: z.strictObject({
    name: z.string(),
    coordinate: publicCoordinateSchema,
  }),
  to: z.strictObject({ name: z.string(), coordinate: publicCoordinateSchema }),
  departureAt: z.iso.datetime({ offset: true }).optional(),
  arrivalAt: z.iso.datetime({ offset: true }).optional(),
  geometry: z.array(publicCoordinateSchema),
  stops: z.array(publicJourneyStopSchema).optional(),
  route: publicJourneyRouteSchema.optional(),
  direction: z.string().optional(),
});

export const publicJourneySchema = z.strictObject({
  durationSeconds: z.number().int().nonnegative(),
  walkingDurationSeconds: z.number().int().nonnegative(),
  transferCount: z.number().int().nonnegative(),
  departureAt: z.iso.datetime({ offset: true }),
  arrivalAt: z.iso.datetime({ offset: true }),
  status: z.enum(["normal", "disrupted", "theoretical"]),
  warnings: z.array(z.string()),
  sections: z.array(publicJourneySectionSchema).min(1),
});

export const publicJourneyShareSnapshotSchema = z.strictObject({
  schemaVersion: z.literal(1),
  journey: publicJourneySchema,
  generatedAt: z.iso.datetime({ offset: true }),
  locale: z.string().min(2).max(32),
  timeZone: z.string().min(1).max(64),
});

export const publicJourneyShareResponseSchema = z.strictObject({
  snapshot: publicJourneyShareSnapshotSchema,
  expiresAt: z.iso.datetime({ offset: true }),
});

export type PublicJourneyShareSnapshot = z.infer<
  typeof publicJourneyShareSnapshotSchema
>;
export type PublicJourneySection = z.infer<typeof publicJourneySectionSchema>;
export type PublicJourney = z.infer<typeof publicJourneySchema>;
export type PublicJourneyShareResponse = z.infer<
  typeof publicJourneyShareResponseSchema
>;

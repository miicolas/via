import * as z from 'zod';

/**
 * What the marketing site is allowed to know about a line.
 *
 * Deliberately not part of `@via/contract`'s main entry point, and not built
 * from it: the contract above `/api` is the agreement with the iOS app, and a
 * procedure added there must never widen what a browser can read. These are
 * their own, narrower shapes — an identity, a condition, and the dates and cut
 * segments of what is disrupting it.
 *
 * They live in the shared package rather than in the API because two sides
 * read them: `apps/api/src/public/lines/projection.ts` produces them, and
 * `apps/marketing` parses them. Declared twice, a renamed field typechecks
 * green on both sides and reaches the browser as `undefined`.
 */
export const publicLineConditionSchema = z.enum([
  'normal',
  'attention',
  'disrupted',
  'suspended',
]);

export const publicLineStatusSchema = z.object({
  id: z.string(),
  mode: z.string(),
  shortName: z.string(),
  condition: publicLineConditionSchema,
  activeCount: z.number().int().min(0),
  summary: z.string().optional(),
  upcoming: z.object({ beginsAt: z.string(), title: z.string().optional() }).optional(),
});

export const publicLineStatusesSchema = z.object({
  source: z.enum(['live', 'unavailable']),
  fetchedAt: z.string().optional(),
  lines: z.array(publicLineStatusSchema),
});

export const publicLineDisruptionSchema = z.object({
  id: z.string(),
  severity: z.enum(['attention', 'disrupted', 'suspended']),
  activity: z.enum(['active', 'upcoming']),
  cause: z.string().optional(),
  title: z.string().optional(),
  periods: z.array(z.object({ beginsAt: z.string(), endsAt: z.string() })),
  /** Station pairs cut on this line — what greys out a segment of the strip. */
  impactedSections: z.array(z.object({ fromName: z.string(), toName: z.string() })),
});

export const publicLineDetailSchema = z.object({
  line: z.object({ id: z.string(), mode: z.string(), shortName: z.string() }),
  source: z.enum(['live', 'unavailable']),
  fetchedAt: z.string().optional(),
  disruptions: z.array(publicLineDisruptionSchema),
});

export type PublicLineCondition = z.infer<typeof publicLineConditionSchema>;
export type PublicLineStatus = z.infer<typeof publicLineStatusSchema>;
export type PublicLineStatuses = z.infer<typeof publicLineStatusesSchema>;
export type PublicLineDisruption = z.infer<typeof publicLineDisruptionSchema>;
export type PublicLineDetail = z.infer<typeof publicLineDetailSchema>;

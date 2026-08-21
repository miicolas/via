import * as z from 'zod';

import {
  journeyDatetimeRepresentsSchema,
  journeyDestinationSchema,
  journeyModeSchema,
  journeysResponseSchema,
} from '../journeys/schema';
import { searchResultSchema } from '../search/schema';

/**
 * POST /natural-journeys carries a free-text phrase, so it never rides in a
 * cacheable GET query string. The body is plain JSON — no query-string coercion
 * needed, unlike {@link journeyInputSchema}.
 */
export const naturalJourneyInputSchema = z
  .object({
    /** The user's phrase. Bounded so a runaway paste can't inflate a prompt. */
    query: z.string().trim().min(1).max(500),
    /** Where the user is, if location was granted. Both coordinates travel together. */
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
    /**
     * The client's temporal context ("now") so the agent can resolve relative
     * phrasing like "dans 20 minutes" against the device clock, not the server's.
     */
    requestedAt: z.iso.datetime({ offset: true }).optional(),
  })
  .refine((input) => (input.latitude === undefined) === (input.longitude === undefined), {
    message: 'latitude et longitude vont ensemble',
  });

/**
 * The intent Via resolved from the phrase, mirroring the on-device
 * `NaturalJourneyInterpretation`. Every field here is grounded in Via's own
 * place resolution and journey engine — never in model free-text.
 */
export const naturalJourneyInterpretationSchema = z.object({
  /** Display label for the origin, e.g. "Ma position" or a resolved place name. */
  originLabel: z.string(),
  /** Absent when the origin is the device's current location. */
  origin: searchResultSchema.optional(),
  destination: journeyDestinationSchema,
  destinationResult: searchResultSchema,
  requestedAt: z.iso.datetime({ offset: true }),
  datetimeRepresents: journeyDatetimeRepresentsSchema,
  requiredModes: z.array(journeyModeSchema),
  excludedModes: z.array(journeyModeSchema),
  preferredModes: z.array(journeyModeSchema),
});

/**
 * The server's answer for an initial submission. It intentionally omits the
 * clarification and decision branches of the on-device `NaturalJourneyResult`:
 * OpenAI only ever produces a resolved plan, a bounded "unsupported", or the
 * recoverable "unavailable" double-failure. Everything after a clarification
 * flows back through the deterministic on-device pipeline instead.
 */
export const naturalJourneyResultSchema = z.discriminatedUnion('outcome', [
  z.object({
    outcome: z.literal('ready'),
    interpretation: naturalJourneyInterpretationSchema,
    journeys: journeysResponseSchema,
  }),
  z.object({
    outcome: z.literal('unsupported'),
    message: z.string(),
    examples: z.array(z.string()),
  }),
  z.object({
    outcome: z.literal('unavailable'),
    message: z.string(),
  }),
]);

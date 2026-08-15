import * as z from 'zod';

import { journeysResponseSchema } from '../journeys/schema';
import { coordinateSchema } from '../shared/schema';

const nativeChatCoordinateSchema = coordinateSchema.extend({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
});

export const nativeChatMessageSchema = z.object({
  role: z.enum(['user', 'assistant']),
  content: z.string().trim().min(1).max(20_000),
});

export const nativeChatRequestSchema = z.object({
  messages: z.array(nativeChatMessageSchema).min(1).max(40),
  location: nativeChatCoordinateSchema.optional(),
});

/**
 * Native chat keeps the destination in the same nested coordinate shape as
 * the Swift domain model. The web chat's tool payload intentionally remains a
 * separate, model-facing shape with flat latitude/longitude fields.
 */
export const nativeChatDestinationSchema = z.object({
  kind: z.enum(['station', 'address']),
  id: z.string().min(1),
  name: z.string().min(1),
  context: z.string().optional(),
  coordinate: coordinateSchema,
});

export const nativeChatEventSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('text_delta'),
    text: z.string(),
  }),
  z.object({
    type: z.literal('itinerary'),
    destination: nativeChatDestinationSchema,
    journeys: journeysResponseSchema,
  }),
  z.object({
    type: z.literal('finished'),
  }),
]);

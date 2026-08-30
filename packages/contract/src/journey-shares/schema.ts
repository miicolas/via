import * as z from "zod";

import {
  journeyClientPayloadSchema,
  journeySchema,
} from "../journeys/schema";
import { capabilityTokenSchema } from "../shared/schema";

/**
 * A journey share is an immutable, deliberately small copy of the journey the
 * traveller chose. It is not a planner request: the recipient must see the
 * same route, timings and warnings that the sender saw.
 */
export const journeyShareSnapshotSchema = z.object({
  schemaVersion: z.literal(1),
  journey: journeySchema,
  generatedAt: z.iso.datetime({ offset: true }),
  locale: z.string().min(2).max(32),
  timeZone: z.string().min(1).max(64),
});

/** Client-created snapshots are bounded; stored snapshots keep the response schema. */
export const journeyShareClientSnapshotSchema = journeyShareSnapshotSchema.extend({
  journey: journeyClientPayloadSchema,
});

/** A URL-safe 256-bit token. The raw token is never stored by the API. */
export const journeyShareTokenSchema = capabilityTokenSchema("journey share token");

export const journeyShareCreateInputSchema = z.object({
  snapshot: journeyShareClientSnapshotSchema,
  /** Client-generated so a retry cannot create duplicate links. */
  idempotencyKey: z.uuid(),
});

export const journeyShareGetInputSchema = z.object({
  token: journeyShareTokenSchema,
});

export const journeyShareResponseSchema = z.object({
  snapshot: journeyShareSnapshotSchema,
  createdAt: z.iso.datetime({ offset: true }),
  expiresAt: z.iso.datetime({ offset: true }),
});

export const journeyShareCreateResponseSchema =
  journeyShareResponseSchema.extend({
    token: journeyShareTokenSchema,
    url: z.url(),
  });

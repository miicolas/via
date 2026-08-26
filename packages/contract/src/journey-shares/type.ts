import * as z from "zod";

import {
  journeyShareCreateInputSchema,
  journeyShareCreateResponseSchema,
  journeyShareResponseSchema,
  journeyShareSnapshotSchema,
} from "./schema";

export type JourneyShareSnapshot = z.infer<typeof journeyShareSnapshotSchema>;
export type JourneyShareCreateInput = z.infer<
  typeof journeyShareCreateInputSchema
>;
export type JourneyShareResponse = z.infer<typeof journeyShareResponseSchema>;
export type JourneyShareCreateResponse = z.infer<
  typeof journeyShareCreateResponseSchema
>;

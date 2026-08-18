import * as z from 'zod';

import {
  departureItemSchema,
  departureGroupSchema,
  departureStatusSchema,
  departuresInputSchema,
  departuresResponseSchema,
} from './schema';

export type DeparturesInput = z.infer<typeof departuresInputSchema>;
export type DepartureStatus = z.infer<typeof departureStatusSchema>;
export type DepartureItem = z.infer<typeof departureItemSchema>;
export type DepartureGroup = z.infer<typeof departureGroupSchema>;
export type DeparturesResponse = z.infer<typeof departuresResponseSchema>;
export type DeparturesSource = DeparturesResponse['source'];

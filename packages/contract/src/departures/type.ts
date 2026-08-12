import * as z from 'zod';

import {
  departureGroupSchema,
  departuresInputSchema,
  departuresResponseSchema,
} from './schema';

export type DeparturesInput = z.infer<typeof departuresInputSchema>;
export type DepartureGroup = z.infer<typeof departureGroupSchema>;
export type DeparturesResponse = z.infer<typeof departuresResponseSchema>;
export type DeparturesSource = DeparturesResponse['source'];

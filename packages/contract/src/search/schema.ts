import * as z from 'zod';

import { coordinateSchema } from '../shared/schema';

export const searchInputSchema = z
  .object({
    q: z.string().trim().min(1).max(200),
    /**
     * Where the user is, if known. It rides along for two jobs: geographic
     * prioritization of address results, and `distanceMeters` on every result.
     * Absent when location permission is denied — results then carry no distance.
     */
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
    limit: z.int().min(1).max(20).default(10),
  })
  .refine((input) => (input.latitude === undefined) === (input.longitude === undefined), {
    message: 'latitude et longitude vont ensemble',
  });

export const stationSearchResultSchema = z.object({
  kind: z.literal('station'),
  /** A `NetworkStation.id`: selecting the result reuses the station path. */
  id: z.string(),
  name: z.string(),
  /** The stop entrance, not a per-line snapped point — right for walking. */
  coordinate: coordinateSchema,
  /** For line badges; resolved against the network map client-side. */
  routeIds: z.array(z.string()),
  distanceMeters: z.number().optional(),
});

export const addressSearchResultSchema = z.object({
  kind: z.literal('address'),
  /** The BAN address id, e.g. "75104_8321_00012". */
  id: z.string(),
  /** The label without locality, e.g. "12 Rue de Rivoli". */
  name: z.string(),
  /** Postcode and city, e.g. "75004 Paris". */
  context: z.string(),
  coordinate: coordinateSchema,
  distanceMeters: z.number().optional(),
});

export const searchResultSchema = z.discriminatedUnion('kind', [
  stationSearchResultSchema,
  addressSearchResultSchema,
]);

export const searchResponseSchema = z.object({
  results: z.array(searchResultSchema),
  /**
   * Whether each upstream source answered. Stations come from our own database
   * and are always present; the BAN geocoder can be down, in which case results
   * simply hold no addresses and the client may say so.
   */
  sources: z.object({
    ban: z.enum(['ok', 'unavailable']),
  }),
});

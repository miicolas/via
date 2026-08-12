import * as z from 'zod';

/**
 * A WGS84 position, named the way map clients want it.
 *
 * GeoJSON would order this `[longitude, latitude]`; the API deliberately does not,
 * because every consumer so far draws it directly.
 */
export const coordinateSchema = z.object({
  latitude: z.number(),
  longitude: z.number(),
});

/** One GTFS shape: a continuous run of track, drawn as a single polyline. */
export const networkSegmentSchema = z.object({
  id: z.string(),
  coordinates: z.array(coordinateSchema),
});

export const networkRouteSchema = z.object({
  id: z.string(),
  shortName: z.string(),
  longName: z.string(),
  /** CSS-ready. GTFS stores these bare ("FFCD00"). */
  color: z.string(),
  textColor: z.string(),
  destinations: z.array(z.string()),
  segments: z.array(networkSegmentSchema),
});

export const networkStationSchema = z.object({
  id: z.string(),
  name: z.string(),
  /**
   * Keyed by route id: an interchange sits at a different snapped point on each
   * line it serves, which is what lets the client move a single station dot as
   * the selected line changes.
   *
   * The keys are also the answer to "which lines serve this station". A separate
   * `routeIds` array used to carry that same fact: built in the same loop, from
   * the same rows, so equal by construction — but with no invariant saying so,
   * and consumers split between trusting one or the other.
   */
  positions: z.record(z.string(), coordinateSchema),
});

export const networkMapSchema = z.object({
  routes: z.array(networkRouteSchema),
  stations: z.array(networkStationSchema),
});

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

export const healthSchema = z.object({
  status: z.literal('ok'),
  db: z.boolean(),
  at: z.iso.datetime(),
});

export type Coordinate = z.infer<typeof coordinateSchema>;
export type SearchInput = z.infer<typeof searchInputSchema>;
export type StationSearchResult = z.infer<typeof stationSearchResultSchema>;
export type AddressSearchResult = z.infer<typeof addressSearchResultSchema>;
export type SearchResult = z.infer<typeof searchResultSchema>;
export type SearchResponse = z.infer<typeof searchResponseSchema>;
export type NetworkSegment = z.infer<typeof networkSegmentSchema>;
export type NetworkRoute = z.infer<typeof networkRouteSchema>;
export type NetworkStation = z.infer<typeof networkStationSchema>;
export type NetworkMap = z.infer<typeof networkMapSchema>;
export type Health = z.infer<typeof healthSchema>;

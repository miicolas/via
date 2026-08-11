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
  segments: z.array(networkSegmentSchema),
});

export const networkStationSchema = z.object({
  id: z.string(),
  name: z.string(),
  routeIds: z.array(z.string()),
  /**
   * Keyed by route id: an interchange sits at a different snapped point on each
   * line it serves, which is what lets the client move a single station dot as
   * the selected line changes.
   */
  positions: z.record(z.string(), coordinateSchema),
});

export const networkMapSchema = z.object({
  routes: z.array(networkRouteSchema),
  stations: z.array(networkStationSchema),
});

export const healthSchema = z.object({
  status: z.literal('ok'),
  db: z.boolean(),
  at: z.iso.datetime(),
});

export type Coordinate = z.infer<typeof coordinateSchema>;
export type NetworkSegment = z.infer<typeof networkSegmentSchema>;
export type NetworkRoute = z.infer<typeof networkRouteSchema>;
export type NetworkStation = z.infer<typeof networkStationSchema>;
export type NetworkMap = z.infer<typeof networkMapSchema>;
export type Health = z.infer<typeof healthSchema>;

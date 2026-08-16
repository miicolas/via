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

export const networkModeSchema = z.enum(['metro', 'rer', 'transilien', 'tram', 'bus']);

/**
 * Exactly what it takes to draw a line badge, inlined into every response that
 * mentions a route (search results, departure groups, the rail map). Inline
 * rather than an id the client resolves against the map payload: a screen can
 * then render its badges from its own response alone, with no second fetch and
 * no pop-in — the precedent set by `journeyRouteSchema`.
 */
export const routeBadgeSchema = z.object({
  id: z.string(),
  shortName: z.string(),
  mode: networkModeSchema,
  /** CSS-ready. GTFS stores these bare ("FFCD00"). */
  color: z.string(),
  textColor: z.string(),
});

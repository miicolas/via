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

/**
 * {@link coordinateSchema} for GET query strings. Swift's OpenAPI runtime
 * serializes whole-number doubles as `"2.0"`, which the smart-coercion plugin
 * refuses to convert (its `Number→String` round-trip yields `"2"`), so query
 * coordinates coerce explicitly. Same JSON Schema output as `z.number()` —
 * the generated OpenAPI document does not change.
 */
export const coordinateParamSchema = z.object({
  latitude: z.coerce.number().min(-90).max(90),
  longitude: z.coerce.number().min(-180).max(180),
});

export const networkModeSchema = z.enum(['metro', 'rer', 'transilien', 'tram', 'bus']);

/**
 * How a wheelchair user can use a station, in Via's vocabulary. Mirrors the
 * `condition` column of `station_facts` — the importer translates IDFM levels
 * into these at write time, so every reader speaks the same three words.
 */
export const accessibilityConditionSchema = z.enum([
  'reservationRequired',
  'staffAssistance',
  'autonomous',
]);

/** Boolean values arrive as `"true"`/`"false"` in a GET query string. */
export const queryBooleanSchema = z.preprocess(
  (value) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  },
  z.boolean()
);

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

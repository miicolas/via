import * as z from 'zod';

import { coordinateSchema, routeBadgeSchema } from '../shared/schema';

/**
 * One continuous run of track, drawn as a single polyline. Not one GTFS shape:
 * the API subtracts the track a route's other patterns already draw, so a
 * pattern can yield several segments (either side of a shared trunk) or none.
 */
export const networkSegmentSchema = z.object({
  id: z.string(),
  coordinates: z.array(coordinateSchema),
});

export const networkRouteSchema = routeBadgeSchema.extend({
  segments: z.array(networkSegmentSchema),
});

export const networkStationSchema = z.object({
  id: z.string(),
  name: z.string(),
  /**
   * One anchor per station — the stop snapped onto its first serving line,
   * which is all the map renders today. Per-line positions will come back on a
   * dedicated per-line endpoint the day a single-line view exists; carrying
   * them for every station cost megabytes nobody read.
   */
  coordinate: coordinateSchema,
  /** Which lines serve this station, resolvable against the response's routes. */
  routeIds: z.array(z.string()),
});

/**
 * The main rail network worth drawing — métro, RER, Transilien and tram —
 * with every station it serves. Bus stops arrive separately, viewport by
 * viewport, through `stationsInArea`.
 */
export const railMapSchema = z.object({
  routes: z.array(networkRouteSchema),
  stations: z.array(networkStationSchema),
});

/**
 * The widest stations query a client may ask, in degrees of latitude or
 * longitude. Bus stops only render at street-level zoom, far below this, so no
 * legitimate viewport ever hits the cap — it exists so a zoomed-out (or
 * hostile) client cannot request all 14 000+ stops in one call.
 */
export const STATIONS_AREA_MAX_SPAN_DEGREES = 0.05;

export const stationsInAreaInputSchema = z
  .object({
    minLatitude: z.number().min(-90).max(90),
    maxLatitude: z.number().min(-90).max(90),
    minLongitude: z.number().min(-180).max(180),
    maxLongitude: z.number().min(-180).max(180),
  })
  .refine(
    (area) => area.minLatitude < area.maxLatitude && area.minLongitude < area.maxLongitude,
    { message: 'la zone doit avoir une étendue positive' }
  )
  .refine(
    (area) =>
      area.maxLatitude - area.minLatitude <= STATIONS_AREA_MAX_SPAN_DEGREES &&
      area.maxLongitude - area.minLongitude <= STATIONS_AREA_MAX_SPAN_DEGREES,
    { message: `la zone ne peut dépasser ${STATIONS_AREA_MAX_SPAN_DEGREES}° de côté` }
  );

export const stationsInAreaSchema = z.object({
  stations: z.array(networkStationSchema),
  /** The badges the stations' `routeIds` point to, deduplicated. */
  routes: z.array(routeBadgeSchema),
});

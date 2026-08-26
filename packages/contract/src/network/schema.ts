import * as z from 'zod';

import {
  accessibilityConditionSchema,
  coordinateSchema,
  routeBadgeSchema,
} from '../shared/schema';

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

export const stationToiletsSchema = z.object({
  label: z.string(),
  detail: z.string().optional(),
});

/** Live Vélib' inventory joined to the station's stable GBFS information. */
export const bikeStationAvailabilitySchema = z.object({
  mechanicalBikes: z.int().min(0),
  electricBikes: z.int().min(0),
  docks: z.int().min(0),
  isInstalled: z.boolean(),
  isRenting: z.boolean(),
  isReturning: z.boolean(),
  lastReportedAt: z.iso.datetime({ offset: true }).optional(),
});

export const bikeStationSchema = z.object({
  id: z.string(),
  stationCode: z.string().optional(),
  name: z.string(),
  coordinate: coordinateSchema,
  capacity: z.int().min(0),
  availability: bikeStationAvailabilitySchema.optional(),
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
  accessibility: z
    .object({
      condition: accessibilityConditionSchema,
      label: z.string(),
      comment: z.string().optional(),
    })
    .optional(),
  /** At least one lift is referenced for this station, regardless of live status. */
  hasElevators: z.boolean().optional(),
  toilets: stationToiletsSchema.optional(),
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
    // Coerced, not plain numbers: see coordinateParamSchema — iOS sends "2.0"
    // for whole-degree tile edges and the coercion plugin leaves those as strings.
    minLatitude: z.coerce.number().min(-90).max(90),
    maxLatitude: z.coerce.number().min(-90).max(90),
    minLongitude: z.coerce.number().min(-180).max(180),
    maxLongitude: z.coerce.number().min(-180).max(180),
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

export const stationCrowdingInputSchema = z.object({
  stationId: z.string().min(1),
});

/**
 * Named after the shared habitual-peak vocabulary (`station-peak`), not
 * `crowdingLevelSchema`: that name belongs to the reports contract, whose
 * live community levels (low…saturated) are a different scale.
 */
export const peakLevelSchema = z.enum(['off', 'moderate', 'peak']);

export const crowdingHourSchema = z.object({
  hour: z.int().min(0).max(23),
  /** peakRatio des validations IDFM, normalisé par station et type de jour (0..1). */
  ratio: z.number().min(0).max(1),
  level: peakLevelSchema,
});

export const crowdingDayProfileSchema = z.array(crowdingHourSchema).length(24);

/**
 * The station's habitual hourly crowding, from the quarterly IDFM validations
 * dataset. Three day types only — the source never distinguishes Monday from
 * Thursday — and rail coverage only: a bus stop legitimately has no profile.
 */
export const stationCrowdingSchema = z.object({
  /** Absent quand la station (bus notamment) n'a aucun profil de validations. */
  profiles: z
    .object({
      weekday: crowdingDayProfileSchema,
      saturday: crowdingDayProfileSchema,
      sunday: crowdingDayProfileSchema,
    })
    .optional(),
});

/**
 * Vélib' docks in the same tile as `stationsInArea`, on their own route.
 *
 * They share the viewport but not the clock: a dock count is a minute old at
 * most while stations and lines change at GTFS import. Riding in one payload
 * forced the whole tile down to bike cadence — a day-long HTTP cache traded
 * away, and ~100 KB of docks sent to every client for a layer that is off by
 * default.
 */
export const bikeStationsInAreaSchema = z.object({
  /** Vélib' stations stay distinct from transit stops and never own route ids. */
  bikeStations: z.array(bikeStationSchema),
  sources: z.object({
    velib: z.enum(['ok', 'unavailable']),
  }),
});

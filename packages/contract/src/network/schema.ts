import * as z from 'zod';

import { coordinateSchema } from '../shared/schema';

/**
 * One continuous run of track, drawn as a single polyline. Not one GTFS shape:
 * the API subtracts the track a route's other patterns already draw, so a
 * pattern can yield several segments (either side of a shared trunk) or none.
 */
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

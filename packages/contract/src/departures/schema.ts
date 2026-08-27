import * as z from 'zod';

import { routeBadgeSchema, stationElevatorSnapshotSchema } from '../shared/schema';

/** How deep the compact station board goes. */
export const DEPARTURES_PER_GROUP = 4;

/** How deep a line-specific service-day board may go. */
export const SERVICE_DAY_DEPARTURES_PER_GROUP = 2_000;

export const departuresInputSchema = z.object({
  /** A `NetworkStation.id` — the client always holds one before asking. */
  stationId: z.string().min(1),
  /** When present, return the complete remaining service-day board for this line. */
  routeId: z.string().min(1).optional(),
});

export const departureStatusSchema = z.enum([
  'on_time',
  'delayed',
  'early',
  'cancelled',
  'missed',
  'arrived',
  'departed',
  'no_report',
  'scheduled',
]);

export const departureItemSchema = z.object({
  /** Stable opaque identity used by clients when an estimate changes. */
  id: z.string().min(1),
  /** Theoretical departure time, when the provider supplies one. */
  scheduledAt: z.iso.datetime({ offset: true }).optional(),
  /** Realtime expected departure time, when the provider supplies one. */
  expectedAt: z.iso.datetime({ offset: true }).optional(),
  /** Signed Expected - Scheduled difference, in seconds. */
  delaySeconds: z.number().int().optional(),
  status: departureStatusSchema,
});

export const departureGroupSchema = z.object({
  /** The line's badge, ready to render without another fetch. */
  route: routeBadgeSchema,
  destination: z.string(),
  /**
   * ISO timestamps of the next departures, soonest first. Timestamps rather
   * than minutes: the payload crosses a shared cache, so the client derives
   * the countdown from its own clock instead of trusting a stale delta.
  */
  departures: z.array(z.iso.datetime({ offset: true })).max(SERVICE_DAY_DEPARTURES_PER_GROUP),
  /** Enriched passage data; `departures` remains during the public transition. */
  departureItems: z.array(departureItemSchema).max(SERVICE_DAY_DEPARTURES_PER_GROUP),
});

export const departuresResponseSchema = z.object({
  /**
   * Where the timestamps come from. `theoretical` is the GTFS-schedule
   * fallback — declared from day one so wiring it in later is not a breaking
   * change. `unavailable` means no source could answer; groups is then empty.
   */
  source: z.enum(['realtime', 'theoretical', 'unavailable']),
  generatedAt: z.iso.datetime({ offset: true }),
  /** Upstream retrieval time; omitted for theoretical and unavailable boards. */
  fetchedAt: z.iso.datetime({ offset: true }).optional(),
  /** Habitual, station-relative profile for the hour when this board was generated. */
  peak: z
    .object({
      ratio: z.number().min(0).max(1),
      level: z.enum(['off', 'moderate', 'peak']),
      label: z.string(),
    })
    .optional(),
  /** Current equipment snapshot for the station detail opened from this board. */
  elevators: stationElevatorSnapshotSchema,
  groups: z.array(departureGroupSchema),
});

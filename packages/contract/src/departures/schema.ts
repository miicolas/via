import * as z from 'zod';

import { routeBadgeSchema } from '../shared/schema';

/** How deep a departure board group goes — the server builds to this cap, the schema enforces it. */
export const DEPARTURES_PER_GROUP = 4;

export const departuresInputSchema = z.object({
  /** A `NetworkStation.id` — the client always holds one before asking. */
  stationId: z.string().min(1),
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
  departures: z.array(z.iso.datetime({ offset: true })).max(DEPARTURES_PER_GROUP),
  /** Enriched passage data; `departures` remains during the public transition. */
  departureItems: z.array(departureItemSchema).max(DEPARTURES_PER_GROUP),
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
  groups: z.array(departureGroupSchema),
});

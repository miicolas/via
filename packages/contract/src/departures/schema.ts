import * as z from 'zod';

import { routeBadgeSchema } from '../shared/schema';

/** How deep a departure board group goes — the server builds to this cap, the schema enforces it. */
export const DEPARTURES_PER_GROUP = 4;

export const departuresInputSchema = z.object({
  /** A `NetworkStation.id` — the client always holds one before asking. */
  stationId: z.string().min(1),
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
});

export const departuresResponseSchema = z.object({
  /**
   * Where the timestamps come from. `theoretical` is the GTFS-schedule
   * fallback — declared from day one so wiring it in later is not a breaking
   * change. `unavailable` means no source could answer; groups is then empty.
   */
  source: z.enum(['realtime', 'theoretical', 'unavailable']),
  generatedAt: z.iso.datetime({ offset: true }),
  groups: z.array(departureGroupSchema),
});

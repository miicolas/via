import * as z from 'zod';

import { routeBadgeSchema } from '../shared/schema';

/**
 * The service level of a whole line, worst active disruption first: IDFM's
 * `information` maps to attention, `perturbee` to disrupted, `bloquante` to
 * suspended. `normal` means no active disruption at all.
 */
export const lineConditionSchema = z.enum(['normal', 'attention', 'disrupted', 'suspended']);

/** A planned disruption starting within the next seven days. */
export const upcomingClosureSchema = z.object({
  beginsAt: z.iso.datetime({ offset: true }),
  title: z.string().optional(),
});

export const lineStatusSchema = z.object({
  /** The line's badge, ready to render without another fetch. */
  route: routeBadgeSchema,
  condition: lineConditionSchema,
  /** Title of the worst active disruption; absent when the line runs normally. */
  summary: z.string().optional(),
  /** How many disruptions are active right now. */
  activeCount: z.int().min(0),
  /** The next planned disruption within seven days, absent when none. */
  upcoming: upcomingClosureSchema.optional(),
});

/**
 * `unavailable` means the disruptions feed could not be read: lines then all
 * carry `normal` and the client must present them as state-unknown rather
 * than healthy.
 */
export const lineStatusesResponseSchema = z.object({
  source: z.enum(['live', 'unavailable']),
  /** Upstream retrieval time; omitted when the feed is unavailable. */
  fetchedAt: z.iso.datetime({ offset: true }).optional(),
  lines: z.array(lineStatusSchema),
});

export const lineSearchInputSchema = z.object({
  q: z.string().trim().min(1).max(100),
  limit: z.int().min(1).max(20).default(10),
});

export const lineDetailInputSchema = z.object({
  /** A `RouteBadge.id` — the client always holds one before asking. */
  lineId: z.string().min(1),
});

export const lineStopSchema = z.object({
  id: z.string(),
  name: z.string(),
});

/**
 * One branch strip of the line: a selected GTFS pattern with its stops in
 * travel order. The canonical pattern of each direction is the line's main
 * trunk; the rest are real branches (`apps/worker/src/pattern-selection.ts`
 * already filtered out depot runs and marginal variants at import time).
 */
export const lineBranchSchema = z.object({
  id: z.string(),
  directionId: z.int(),
  /** The terminus label riders know the branch by, e.g. "Boissy-St-Léger". */
  headsign: z.string(),
  isCanonical: z.boolean(),
  stops: z.array(lineStopSchema),
});

export const disruptionPeriodSchema = z.object({
  beginsAt: z.iso.datetime({ offset: true }),
  endsAt: z.iso.datetime({ offset: true }),
});

/** A cut segment; stop ids resolve against the branches' stops. */
export const impactedSectionSchema = z.object({
  fromStopId: z.string(),
  fromName: z.string(),
  toStopId: z.string(),
  toName: z.string(),
});

export const lineDisruptionSchema = z.object({
  id: z.string(),
  severity: z.enum(['attention', 'disrupted', 'suspended']),
  activity: z.enum(['active', 'upcoming']),
  cause: z.string().optional(),
  title: z.string().optional(),
  /** Plain text, paragraphs separated by newlines. */
  message: z.string().optional(),
  periods: z.array(disruptionPeriodSchema),
  impactedSections: z.array(impactedSectionSchema),
  updatedAt: z.iso.datetime({ offset: true }).optional(),
});

export const lineDetailResponseSchema = z.object({
  route: routeBadgeSchema,
  branches: z.array(lineBranchSchema),
  source: z.enum(['live', 'unavailable']),
  fetchedAt: z.iso.datetime({ offset: true }).optional(),
  /** Active disruptions first, then upcoming ones by start time. */
  disruptions: z.array(lineDisruptionSchema),
});

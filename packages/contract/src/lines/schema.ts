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

/** A station of the complete line schema. */
export const lineSchemaStopSchema = z.object({
  id: z.string(),
  name: z.string(),
  /** Served by at least one other metro, RER, Transilien or tram line. */
  isInterchange: z.boolean(),
});

/**
 * A run of consecutive stations sharing the same service: the trunk that
 * every train of the direction serves, or a branch ("Branche Cergy-le-Haut",
 * "Branches Cergy-le-Haut / Poissy" for a shared sub-trunk).
 */
export const lineSchemaSectionSchema = z.object({
  role: z.enum(['trunk', 'branch']),
  /** Absent for the trunk. */
  label: z.string().optional(),
  /**
   * Origin and terminus stops of the service groups whose trains call in this
   * section — the trunk lists every group, a branch only its own. Two
   * sections lie on one physical path iff their groups intersect on both
   * sides; that is how a disruption spanning trunk, shared sub-trunk and leaf
   * branch projects onto the schema.
   */
  origins: z.array(z.string()),
  termini: z.array(z.string()),
  stops: z.array(lineSchemaStopSchema),
});

/**
 * One direction of the line, complete: every station merged from all trips at
 * import time (`apps/worker/src/line-schema/`), not one mission's calls.
 */
export const lineDirectionSchema = z.object({
  directionId: z.int(),
  /** Real termini riders know the direction by, e.g. "Boissy / Marne-la-Vallée". */
  label: z.string(),
  /** Sections in travel order: origin branches, trunk, destination branches. */
  sections: z.array(lineSchemaSectionSchema),
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
  /**
   * @deprecated One representative mission's calls per pattern — a skip-stop
   * subset of the line. Kept because shipped TestFlight builds decode it as a
   * required key; new clients read `directions`.
   */
  branches: z.array(lineBranchSchema),
  /** The complete schema of the line, one entry per direction of travel. */
  directions: z.array(lineDirectionSchema),
  source: z.enum(['live', 'unavailable']),
  fetchedAt: z.iso.datetime({ offset: true }).optional(),
  /** Active disruptions first, then upcoming ones by start time. */
  disruptions: z.array(lineDisruptionSchema),
});

/**
 * The complete, rider-facing schema of one direction of a line.
 *
 * A GTFS feed describes a direction as hundreds of trip variants: semi-direct
 * missions that skip stations, short turns, night termini, depot runs. No
 * single trip serves every station, so the full schema only exists as the
 * *merge* of all of them. This module is that merge, and like
 * `pattern-selection.ts` it is deliberately a pure module — no CSV, no
 * database — because which variants count as "the line" is a judgement call.
 */

export type LineVariant = {
  /** Canonical stop ids in travel order (platform aliases already collapsed). */
  stopIds: string[];
  tripCount: number;
};

export type SchemaSection = {
  role: 'trunk' | 'branch';
  /**
   * Origin and terminus stops of the service groups whose trains call in this
   * section, busiest first — the trunk lists every group, a branch only its
   * own. Two sections lie on one physical path iff their groups intersect on
   * both sides, which is how a client projects a disruption across sections.
   */
  origins: string[];
  termini: string[];
  /** Stops of the section in travel order. */
  stopIds: string[];
};

export type LineSchema = {
  /** Sections in travel order: origin branches, trunk, destination branches. */
  sections: SchemaSection[];
  /** Real origins/termini of the direction, busiest first. */
  originStopIds: string[];
  terminusStopIds: string[];
  /** Anything worth a log line at import time (cycles broken, fallbacks). */
  warnings: string[];
};

/**
 * An origin or terminus serving fewer than a twentieth of the direction's
 * trips is not a branch end, it is noise — a night terminus, a depot run.
 */
export const MIN_GROUP_SHARE = 0.05;

/**
 * A stop served by fewer than a hundredth of the direction's trips only
 * exists because of exceptional diversions. Skip-stop missions cannot push a
 * real station under this bar: its all-stops missions serve it heavily.
 */
export const MIN_STOP_SHARE = 0.01;
export const MIN_STOP_TRIPS = 2;

export function buildLineSchema(rawVariants: LineVariant[]): LineSchema {
  const warnings: string[] = [];
  let variants = rawVariants
    .map((variant) => ({ ...variant, stopIds: collapseConsecutive(variant.stopIds) }))
    .filter((variant) => variant.stopIds.length >= 2);
  if (variants.length === 0) {
    return { sections: [], originStopIds: [], terminusStopIds: [], warnings };
  }

  // Drop variants whose origin or terminus group is too marginal to be real.
  const total = sumTrips(variants);
  const originCounts = endCounts(variants, first);
  const terminusCounts = endCounts(variants, last);
  const survivors = variants.filter(
    (variant) =>
      originCounts.get(first(variant))! >= MIN_GROUP_SHARE * total &&
      terminusCounts.get(last(variant))! >= MIN_GROUP_SHARE * total
  );
  if (survivors.length === 0) {
    // Pathological feed (every end marginal): degrade to the busiest variant.
    warnings.push('every origin/terminus group below share threshold; kept busiest variant');
    variants = [variants.toSorted((a, b) => b.tripCount - a.tripCount)[0]!];
  } else {
    variants = survivors;
  }

  const keptTotal = sumTrips(variants);
  const keptOrigins = endCounts(variants, first);
  const keptTermini = endCounts(variants, last);
  const endStops = new Set([...keptOrigins.keys(), ...keptTermini.keys()]);

  // Drop diversion-only stops, then re-thread each variant without them.
  const stopTrips = new Map<string, number>();
  for (const variant of variants) {
    for (const stopId of new Set(variant.stopIds)) {
      stopTrips.set(stopId, (stopTrips.get(stopId) ?? 0) + variant.tripCount);
    }
  }
  const stopFloor = Math.max(MIN_STOP_TRIPS, MIN_STOP_SHARE * keptTotal);
  const keptStop = (stopId: string) =>
    endStops.has(stopId) || stopTrips.get(stopId)! >= stopFloor;
  const droppedStops = [...stopTrips.keys()].filter((stopId) => !keptStop(stopId));
  if (droppedStops.length > 0) {
    warnings.push(`dropped ${droppedStops.length} diversion-only stops`);
  }
  const threaded = variants.map((variant) => ({
    ...variant,
    stopIds: collapseConsecutive(variant.stopIds.filter(keptStop)),
  }));

  const order = topologicalOrder(threaded, stopTrips, warnings);
  const orderIndex = new Map(order.map((stopId, index) => [stopId, index]));

  // Classify each stop by which service groups reach it: the trunk is what
  // every group serves; every other signature class is one branch section.
  // This handles branches at both ends and shared sub-trunks (Cergy/Poissy
  // between Houilles and Maisons-Laffitte) without any fork geometry.
  const originsServing = new Map<string, Set<string>>();
  const terminiServing = new Map<string, Set<string>>();
  for (const variant of threaded) {
    for (const stopId of variant.stopIds) {
      addTo(originsServing, stopId, first(variant));
      addTo(terminiServing, stopId, last(variant));
    }
  }
  // Short turns are not branches. A service group whose stops are all served
  // by another group too — trains terminating at Gare du Nord, at Denfert, at
  // Noisy-le-Grand — adds no station to the schema, only a signature that
  // shatters the trunk into unreadable slivers. Dropping those groups is what
  // makes the trunk a trunk again.
  const realOrigins = branchEnds(originsServing, keptOrigins);
  const realTermini = branchEnds(terminiServing, keptTermini);
  for (const stopId of [...originsServing.keys()]) {
    originsServing.set(stopId, intersect(originsServing.get(stopId)!, realOrigins));
    terminiServing.set(stopId, intersect(terminiServing.get(stopId)!, realTermini));
  }

  const byTrips = (counts: Map<string, number>) => (a: string, b: string) =>
    counts.get(b)! - counts.get(a)! || compare(a, b);

  const sectionsByKey = new Map<string, { origins: string[]; termini: string[]; stopIds: string[] }>();
  for (const stopId of order) {
    const origins = [...originsServing.get(stopId)!].sort(byTrips(keptOrigins));
    const termini = [...terminiServing.get(stopId)!].sort(byTrips(keptTermini));
    const key = `${origins.join(' ')}\u0000${termini.join(' ')}`;
    const section = sectionsByKey.get(key);
    if (section) {
      section.stopIds.push(stopId);
    } else {
      sectionsByKey.set(key, { origins, termini, stopIds: [stopId] });
    }
  }

  const sections: SchemaSection[] = [...sectionsByKey.values()]
    .toSorted((a, b) => orderIndex.get(a.stopIds[0]!)! - orderIndex.get(b.stopIds[0]!)!)
    .map(({ origins, termini, stopIds }) => ({
      role:
        origins.length === realOrigins.size && termini.length === realTermini.size
          ? ('trunk' as const)
          : ('branch' as const),
      origins,
      termini,
      stopIds,
    }));

  return {
    sections,
    originStopIds: [...realOrigins].sort(byTrips(keptOrigins)),
    terminusStopIds: [...realTermini].sort(byTrips(keptTermini)),
    warnings,
  };
}

/**
 * Which origin (or terminus) groups are real branch ends: the ones that are,
 * somewhere, the only group serving a station. A group failing that test is a
 * short turn riding on another group's tracks, so it is dropped — least busy
 * first, re-testing after each drop, and never the last group standing. Every
 * station therefore keeps at least one serving group.
 */
function branchEnds(
  serving: Map<string, Set<string>>,
  counts: Map<string, number>
): Set<string> {
  const groups = new Set(counts.keys());
  while (groups.size > 1) {
    const exclusive = new Set<string>();
    for (const servers of serving.values()) {
      const kept = [...servers].filter((group) => groups.has(group));
      if (kept.length === 1) exclusive.add(kept[0]!);
    }
    const shortTurns = [...groups]
      .filter((group) => !exclusive.has(group))
      .sort((a, b) => counts.get(a)! - counts.get(b)! || compare(a, b));
    if (shortTurns.length === 0) break;
    groups.delete(shortTurns[0]!);
  }
  return groups;
}

function intersect(values: Set<string>, kept: Set<string>): Set<string> {
  return new Set([...values].filter((value) => kept.has(value)));
}

/**
 * Merge every variant's partial order into one global stop order (Kahn).
 * Ready stops are taken busiest first, then by their position in the busiest
 * variant, then by id — the same input always yields the same schema. A cycle
 * (looping missions, RER C territory) is broken by discarding its lightest
 * edge: the order degrades locally, the import never fails.
 */
function topologicalOrder(
  variants: LineVariant[],
  stopTrips: Map<string, number>,
  warnings: string[]
): string[] {
  const nodes = new Set(variants.flatMap((variant) => variant.stopIds));
  const edges = new Map<string, Map<string, number>>();
  for (const variant of variants) {
    for (let i = 0; i + 1 < variant.stopIds.length; i += 1) {
      const from = variant.stopIds[i]!;
      const to = variant.stopIds[i + 1]!;
      if (from === to) continue;
      const out = edges.get(from) ?? new Map<string, number>();
      out.set(to, (out.get(to) ?? 0) + variant.tripCount);
      edges.set(from, out);
    }
  }

  const indegree = new Map<string, number>([...nodes].map((node) => [node, 0]));
  for (const out of edges.values()) {
    for (const to of out.keys()) indegree.set(to, indegree.get(to)! + 1);
  }

  const busiest = variants.toSorted((a, b) => b.tripCount - a.tripCount)[0];
  const busiestIndex = new Map(busiest?.stopIds.map((stopId, index) => [stopId, index]));
  const pickNext = (a: string, b: string) =>
    stopTrips.get(b)! - stopTrips.get(a)! ||
    (busiestIndex.get(a) ?? Infinity) - (busiestIndex.get(b) ?? Infinity) ||
    compare(a, b);

  const order: string[] = [];
  const remaining = new Set(nodes);
  while (remaining.size > 0) {
    const ready = [...remaining].filter((node) => indegree.get(node) === 0);
    if (ready.length === 0) {
      dropLightestEdge(edges, indegree, remaining, warnings);
      continue;
    }
    const node = ready.toSorted(pickNext)[0]!;
    order.push(node);
    remaining.delete(node);
    for (const to of edges.get(node)?.keys() ?? []) {
      if (remaining.has(to)) indegree.set(to, indegree.get(to)! - 1);
    }
  }
  return order;
}

function dropLightestEdge(
  edges: Map<string, Map<string, number>>,
  indegree: Map<string, number>,
  remaining: Set<string>,
  warnings: string[]
) {
  let lightest: { from: string; to: string; weight: number } | undefined;
  for (const [from, out] of edges) {
    if (!remaining.has(from)) continue;
    for (const [to, weight] of out) {
      if (!remaining.has(to)) continue;
      if (!lightest || weight < lightest.weight) lightest = { from, to, weight };
    }
  }
  // Unreachable unless the graph is corrupt: a stall implies a cycle, and a
  // cycle within `remaining` always exposes at least one candidate edge.
  if (!lightest) throw new Error('stop graph stalled without a droppable edge');
  edges.get(lightest.from)!.delete(lightest.to);
  indegree.set(lightest.to, indegree.get(lightest.to)! - 1);
  warnings.push(`cycle broken at ${lightest.from} → ${lightest.to}`);
}

function collapseConsecutive(stopIds: string[]): string[] {
  return stopIds.filter((stopId, index) => stopId !== stopIds[index - 1]);
}

function endCounts(variants: LineVariant[], end: (variant: LineVariant) => string) {
  const counts = new Map<string, number>();
  for (const variant of variants) {
    counts.set(end(variant), (counts.get(end(variant)) ?? 0) + variant.tripCount);
  }
  return counts;
}

function addTo(map: Map<string, Set<string>>, key: string, value: string) {
  const set = map.get(key) ?? new Set<string>();
  set.add(value);
  map.set(key, set);
}

function sumTrips(variants: LineVariant[]) {
  return variants.reduce((sum, variant) => sum + variant.tripCount, 0);
}

const first = (variant: LineVariant) => variant.stopIds[0]!;
const last = (variant: LineVariant) => variant.stopIds[variant.stopIds.length - 1]!;
const compare = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

/**
 * Which branches of a metro line the map is allowed to draw.
 *
 * This is the editorial policy of the whole map, and it is deliberately a pure
 * module: no CSV, no database, no imports at all. A GTFS feed describes a line as
 * hundreds of trip variants; almost all of them are the same track with a
 * different terminus or a depot run. Picking the handful that a rider would
 * recognise as "the line" is a judgement call, and this is where it lives.
 */

export type PatternCandidate = {
  routeId: string;
  directionId: number;
  headsign: string;
  shapeId: string;
  representativeTripId: string;
  tripCount: number;
};

/**
 * A branch running fewer than a tenth of the trips of its direction's busiest
 * headsign is not a branch, it is noise — a night terminus, a depot run, a
 * handful of diverted trips. Drawing them turns a metro map into a spider web.
 */
export const MIN_BRANCH_SHARE = 0.1;

/**
 * Keeps, per direction, the busiest branch of each headsign — minus the ones too
 * marginal to be a real branch — and names the busiest of them the canonical one.
 */
export function selectPatterns(candidates: PatternCandidate[], routeId: string) {
  const byDirection = Map.groupBy(candidates, (candidate) => candidate.directionId);
  const selectedByShape = new Map<string, PatternCandidate>();

  for (const directionCandidates of byDirection.values()) {
    const byHeadsign = Map.groupBy(directionCandidates, (candidate) => candidate.headsign);
    const primaryByHeadsign = [...byHeadsign.values()].map((headsignCandidates) =>
      headsignCandidates.toSorted((a, b) => b.tripCount - a.tripCount)[0]!
    );
    const busiest = Math.max(...primaryByHeadsign.map((candidate) => candidate.tripCount));

    for (const candidate of primaryByHeadsign) {
      if (candidate.tripCount < busiest * MIN_BRANCH_SHARE) continue;
      const current = selectedByShape.get(candidate.shapeId);
      if (!current || candidate.tripCount > current.tripCount) {
        selectedByShape.set(candidate.shapeId, candidate);
      }
    }
  }

  const patterns = [...selectedByShape.values()];
  const [first] = patterns;
  if (!first) throw new Error(`No representative pattern found for ${routeId}`);
  const canonical = patterns.reduce(
    (best, pattern) => (pattern.tripCount > best.tripCount ? pattern : best),
    first
  );
  return { patterns, canonicalShapeId: canonical.shapeId };
}

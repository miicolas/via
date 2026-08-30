import type { NormalizedDisruption } from "../routers/lines/disruptions/parse";

// Keyed on the snapshot object, so a new poll's disruptions hash afresh while
// one tick's N recipients share a single hash.
const disruptionVersions = new WeakMap<NormalizedDisruption, string>();

export function disruptionVersion(disruption: NormalizedDisruption): string {
  const cached = disruptionVersions.get(disruption);
  if (cached !== undefined) return cached;
  const version = computeDisruptionVersion(disruption);
  disruptionVersions.set(disruption, version);
  return version;
}

function computeDisruptionVersion(disruption: NormalizedDisruption): string {
  const explicitVersion = disruption.updatedAt;
  if (explicitVersion !== undefined) {
    return `${explicitVersion}:${disruption.severity}`;
  }

  const value = JSON.stringify({
    severity: disruption.severity,
    cause: disruption.cause,
    title: disruption.title,
    message: disruption.message,
    routeIds: disruption.routeIds,
    periods: disruption.periods,
  });
  let hash = 2166136261;
  for (const character of value) {
    hash ^= character.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return `${disruption.severity}:${(hash >>> 0).toString(16)}`;
}

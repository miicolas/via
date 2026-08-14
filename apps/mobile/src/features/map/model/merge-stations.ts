import type { NetworkStation } from '@via/contract';

/**
 * The stations the map shows: the rail map's — always loaded, anchored on
 * their line — joined by whatever the viewport tiles brought in. When both
 * know a station, rail wins the coordinate (it is snapped to the drawn track)
 * and the route lists union, so an interchange keeps its bus badges without
 * its dot jumping off the line.
 */
export function mergeStations(
  railStations: NetworkStation[],
  areaStations: NetworkStation[]
): NetworkStation[] {
  if (areaStations.length === 0) return railStations;

  const byId = new Map(railStations.map((station) => [station.id, station]));
  const merged = [...railStations];

  for (const station of areaStations) {
    const existing = byId.get(station.id);
    if (!existing) {
      byId.set(station.id, station);
      merged.push(station);
      continue;
    }

    const extraRouteIds = station.routeIds.filter((id) => !existing.routeIds.includes(id));
    if (extraRouteIds.length === 0) continue;

    const combined = { ...existing, routeIds: [...existing.routeIds, ...extraRouteIds] };
    byId.set(station.id, combined);
    merged[merged.indexOf(existing)] = combined;
  }

  return merged;
}

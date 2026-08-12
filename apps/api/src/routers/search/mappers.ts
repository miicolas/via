import type { StationSearchResult } from '@via/contract';

import type { MatchingStationRow } from './queries';

export function toStationResults(rows: MatchingStationRow[]): StationSearchResult[] {
  return rows.map((row) => ({
    kind: 'station' as const,
    id: row.id,
    name: row.name,
    // ST_X/ST_Y come back as strings from some drivers; Number() settles it,
    // like the network mapper does.
    coordinate: { latitude: Number(row.latitude), longitude: Number(row.longitude) },
    routeIds: row.routeIds,
  }));
}

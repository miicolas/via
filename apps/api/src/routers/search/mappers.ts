import type { StationSearchResult } from '@via/contract';

import { toRouteBadge } from '../route-badge';
import type { MatchingStationRow } from './queries';

export function toStationResults(rows: MatchingStationRow[]): StationSearchResult[] {
  return rows.map((row) => ({
    kind: 'station' as const,
    id: row.id,
    name: row.name,
    // ST_X/ST_Y come back as strings from some drivers; Number() settles it,
    // like the network mapper does.
    coordinate: { latitude: Number(row.latitude), longitude: Number(row.longitude) },
    routes: row.routes.map(toRouteBadge),
    accessibility: accessibilityOf(row),
  }));
}

function accessibilityOf(row: MatchingStationRow) {
  if (row.accessibilityLevelId === undefined || row.accessibilityLevelId === null) {
    return undefined;
  }
  switch (row.accessibilityLevelId) {
    case 3:
      return {
        condition: 'reservationRequired' as const,
        label: 'Sur réservation',
        comment: row.accessibilityComment ?? undefined,
      };
    case 4:
      return {
        condition: 'staffAssistance' as const,
        label: 'Avec un agent',
        comment: row.accessibilityComment ?? undefined,
      };
    case 6:
      return {
        condition: 'autonomous' as const,
        label: 'En autonomie',
        comment: row.accessibilityComment ?? undefined,
      };
    default:
      return undefined;
  }
}

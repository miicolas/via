import type { StationSearchResult } from '@via/contract';

import { ACCESSIBILITY_CONDITION_LABELS } from '../accessibility-labels';
import { compareRouteBadges, toRouteBadge } from '../route-badge';
import type { MatchingStationRow } from './queries';

export function toStationResults(rows: MatchingStationRow[]): StationSearchResult[] {
  return rows.map((row) => ({
    kind: 'station' as const,
    id: row.id,
    name: row.name,
    // ST_X/ST_Y come back as strings from some drivers; Number() settles it,
    // like the network mapper does.
    coordinate: { latitude: Number(row.latitude), longitude: Number(row.longitude) },
    routes: row.routes.map(toRouteBadge).sort(compareRouteBadges),
    accessibility: accessibilityOf(row),
  }));
}

function accessibilityOf(row: MatchingStationRow) {
  const condition = row.accessibilityCondition;
  if (condition === null) return undefined;
  return {
    condition,
    label: ACCESSIBILITY_CONDITION_LABELS[condition],
    comment: row.accessibilityDetail ?? undefined,
  };
}

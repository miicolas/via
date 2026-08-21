import type { StationsInArea } from '@via/contract';

import { toRouteBadge, type RouteBadgeRow } from '../route-badge';
import { ACCESSIBILITY_CONDITION_LABELS } from '../accessibility-labels';
import type { StationInAreaRow } from './queries';

/**
 * Area rows → contract. Stations carry `routeIds`; the badges land once in
 * `routes`, deduplicated across the whole area, so a corridor served by the
 * same lines does not repeat five badges per stop.
 */
export function toStationsInArea(rows: StationInAreaRow[]): StationsInArea {
  const badgeRows = new Map<string, RouteBadgeRow>();

  return {
    stations: rows.map((row) => {
      for (const route of row.routes) badgeRows.set(route.id, route);

      return {
        id: row.id,
        name: row.name,
        // The raw stop entrance, exactly what the full map used to serve for
        // bus stops. ST_X/ST_Y come back as strings from some drivers.
        coordinate: { latitude: Number(row.latitude), longitude: Number(row.longitude) },
        routeIds: row.routes.map((route) => route.id),
        ...(row.accessibilityCondition
          ? { accessibility: {
              condition: row.accessibilityCondition,
              label: ACCESSIBILITY_CONDITION_LABELS[row.accessibilityCondition],
              comment: row.accessibilityDetail ?? undefined,
            } }
          : {}),
      };
    }),
    routes: [...badgeRows.values()].map(toRouteBadge),
  };
}

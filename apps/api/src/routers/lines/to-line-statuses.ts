import type { LineStatus, LineStatusesResponse } from '@via/contract';

import type { DisruptionsSnapshot } from './disruptions/snapshot';
import type { LineRow } from './queries';
import { lineServiceState } from './service-state';
import { toRouteBadge } from '../route-badge';

const MODE_ORDER: Record<string, number> = { metro: 0, rer: 1, transilien: 2, tram: 3, bus: 4 };

/**
 * Line rows + the disruptions snapshot → the statuses payload. `canonical`
 * order is the tab's fixed listing (modes in display order, then natural code
 * order); `given` preserves the caller's ranking, e.g. search relevance.
 */
export function toLineStatuses(
  rows: LineRow[],
  snapshot: DisruptionsSnapshot | null,
  now: Date,
  order: 'canonical' | 'given' = 'canonical'
): LineStatusesResponse {
  const nowSeconds = Math.floor(now.getTime() / 1_000);

  const lines: LineStatus[] = rows.map((row) => {
    const route = toRouteBadge(row);
    const state = snapshot
      ? lineServiceState(row.id, snapshot.disruptions, nowSeconds)
      : { condition: 'normal' as const, activeCount: 0 };

    return {
      route,
      condition: state.condition,
      ...(state.summary === undefined ? {} : { summary: state.summary }),
      activeCount: state.activeCount,
      ...(state.upcoming === undefined
        ? {}
        : {
            upcoming: {
              beginsAt: new Date(state.upcoming.beginsAt * 1_000).toISOString(),
              ...(state.upcoming.title === undefined ? {} : { title: state.upcoming.title }),
            },
          }),
    };
  });

  if (order === 'canonical') {
    lines.sort(
      (left, right) =>
        MODE_ORDER[left.route.mode] - MODE_ORDER[right.route.mode] ||
        left.route.shortName.localeCompare(right.route.shortName, 'fr', { numeric: true })
    );
  }

  return {
    source: snapshot ? 'live' : 'unavailable',
    ...(snapshot ? { fetchedAt: new Date(snapshot.fetchedAt * 1_000).toISOString() } : {}),
    lines,
  };
}

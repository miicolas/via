import type { SearchResult } from '@via/contract';

import type { RecentSearchSnapshot } from './recent-searches';

/**
 * The single definition of what gets persisted for a recent search: accepts a
 * live result or an already-stored snapshot and keeps only the whitelisted
 * fields, so extra fields (distance, storage leftovers) never leak through.
 */
export function toRecentSearchSnapshot(
  result: SearchResult | RecentSearchSnapshot
): RecentSearchSnapshot {
  if (result.kind === 'station') {
    return {
      kind: result.kind,
      id: result.id,
      name: result.name,
      coordinate: result.coordinate,
      routes: result.routes,
    };
  }

  return {
    kind: result.kind,
    id: result.id,
    name: result.name,
    context: result.context,
    coordinate: result.coordinate,
  };
}

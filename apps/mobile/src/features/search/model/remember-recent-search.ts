import type { SearchResult } from '@via/contract';

import { MAX_RECENT_SEARCHES, type RecentSearchSnapshot } from './recent-searches';
import { recentSearchKey } from './recent-search-key';
import { toRecentSearchSnapshot } from './to-recent-search-snapshot';

export function rememberRecentSearch(
  entries: RecentSearchSnapshot[],
  result: SearchResult | RecentSearchSnapshot
): RecentSearchSnapshot[] {
  const snapshot = toRecentSearchSnapshot(result);
  const key = recentSearchKey(snapshot);

  return [snapshot, ...entries.filter((entry) => recentSearchKey(entry) !== key)].slice(
    0,
    MAX_RECENT_SEARCHES
  );
}

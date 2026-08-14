import type { RecentSearchSnapshot } from './recent-searches';
import { recentSearchKey } from './recent-search-key';

export function removeRecentSearch(
  entries: RecentSearchSnapshot[],
  key: string
): RecentSearchSnapshot[] {
  return entries.filter((entry) => recentSearchKey(entry) !== key);
}

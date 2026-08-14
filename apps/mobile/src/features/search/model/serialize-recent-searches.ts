import {
  MAX_RECENT_SEARCHES,
  RECENT_SEARCH_STORAGE_VERSION,
  type RecentSearchSnapshot,
} from './recent-searches';

export function serializeRecentSearches(entries: RecentSearchSnapshot[]): string {
  return JSON.stringify({
    version: RECENT_SEARCH_STORAGE_VERSION,
    entries: entries.slice(0, MAX_RECENT_SEARCHES),
  });
}

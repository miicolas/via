import 'expo-sqlite/localStorage/install';

import type { SearchResult } from '@via/contract';
import { useCallback, useMemo, useState } from 'react';

import { parseRecentSearches } from '@/features/search/model/parse-recent-searches';
import {
  RECENT_SEARCH_STORAGE_KEY,
  type RecentSearchSnapshot,
} from '@/features/search/model/recent-searches';
import { rememberRecentSearch } from '@/features/search/model/remember-recent-search';
import { removeRecentSearch } from '@/features/search/model/remove-recent-search';
import { recentSearchKey } from '@/features/search/model/recent-search-key';
import { serializeRecentSearches } from '@/features/search/model/serialize-recent-searches';

export type RecentSearchesState = {
  entries: RecentSearchSnapshot[];
  remember: (result: SearchResult | RecentSearchSnapshot) => void;
  remove: (search: RecentSearchSnapshot) => void;
};

export function useRecentSearches(): RecentSearchesState {
  const [entries, setEntries] = useState<RecentSearchSnapshot[]>(readRecentSearches);

  // Stable callbacks and a stable state object: this hook feeds the map
  // provider's context value, so a fresh object per render would re-render
  // every sheet on the screen.
  const remember = useCallback((result: SearchResult | RecentSearchSnapshot) => {
    setEntries((current) => {
      const next = rememberRecentSearch(current, result);
      writeRecentSearches(next);
      return next;
    });
  }, []);

  const remove = useCallback((search: RecentSearchSnapshot) => {
    setEntries((current) => {
      const next = removeRecentSearch(current, recentSearchKey(search));
      writeRecentSearches(next);
      return next;
    });
  }, []);

  return useMemo(() => ({ entries, remember, remove }), [entries, remember, remove]);
}

function readRecentSearches(): RecentSearchSnapshot[] {
  try {
    return parseRecentSearches(globalThis.localStorage?.getItem(RECENT_SEARCH_STORAGE_KEY) ?? null);
  } catch {
    return [];
  }
}

function writeRecentSearches(entries: RecentSearchSnapshot[]) {
  try {
    globalThis.localStorage?.setItem(
      RECENT_SEARCH_STORAGE_KEY,
      serializeRecentSearches(entries)
    );
  } catch {
    // Recent searches are a convenience; a storage failure must not affect search.
  }
}

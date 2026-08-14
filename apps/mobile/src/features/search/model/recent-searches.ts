import type { AddressSearchResult, StationSearchResult } from '@via/contract';

export const MAX_RECENT_SEARCHES = 5;
export const RECENT_SEARCH_STORAGE_KEY = 'via.recent-searches.v1';
export const RECENT_SEARCH_STORAGE_VERSION = 1;

export type RecentSearchSnapshot =
  | Pick<StationSearchResult, 'kind' | 'id' | 'name' | 'coordinate' | 'routes'>
  | Pick<AddressSearchResult, 'kind' | 'id' | 'name' | 'context' | 'coordinate'>;

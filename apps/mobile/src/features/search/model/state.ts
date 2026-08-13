import type { SearchResponse, SearchResult } from '@via/contract';

/**
 * A network completion, tagged with the query it answered. No `response` means
 * the request failed. The tag is the staleness guard: aborting the previous
 * request is not enough, a response already in flight would still land.
 */
export type SettledSearch = {
  forQuery: string;
  response?: SearchResponse;
};

export type SearchState = {
  status: 'idle' | 'loading' | 'ready' | 'error';
  results: SearchResult[];
  banUnavailable: boolean;
};

/**
 * Derives what the results list shows from the current query and the last
 * completion. While a fresh answer is on its way, the stale list keeps
 * painting — blanking it on every keystroke would flicker.
 */
export function searchState(query: string, settled?: SettledSearch): SearchState {
  const currentQuery = query.trim();
  if (!currentQuery) return { status: 'idle', results: [], banUnavailable: false };

  if (!settled || settled.forQuery !== currentQuery) {
    return { status: 'loading', results: settled?.response?.results ?? [], banUnavailable: false };
  }

  if (!settled.response) return { status: 'error', results: [], banUnavailable: false };

  return {
    status: 'ready',
    results: settled.response.results,
    banUnavailable: settled.response.sources.ban === 'unavailable',
  };
}

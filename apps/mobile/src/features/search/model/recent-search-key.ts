import type { RecentSearchSnapshot } from './recent-searches';

export function recentSearchKey(search: Pick<RecentSearchSnapshot, 'kind' | 'id'>): string {
  return `${search.kind}:${search.id}`;
}

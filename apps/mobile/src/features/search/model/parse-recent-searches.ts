import type { Coordinate, RouteBadge } from '@via/contract';

import {
  MAX_RECENT_SEARCHES,
  RECENT_SEARCH_STORAGE_VERSION,
  type RecentSearchSnapshot,
} from './recent-searches';
import { recentSearchKey } from './recent-search-key';
import { toRecentSearchSnapshot } from './to-recent-search-snapshot';

type RecentSearchStorage = {
  version: typeof RECENT_SEARCH_STORAGE_VERSION;
  entries: RecentSearchSnapshot[];
};

export function parseRecentSearches(value: string | null): RecentSearchSnapshot[] {
  if (!value) return [];

  try {
    const parsed: unknown = JSON.parse(value);
    if (!isRecentSearchStorage(parsed)) return [];

    const entries = parsed.entries.map(toRecentSearchSnapshot);
    return entries
      .filter(
        (entry, index) =>
          entries.findIndex(
            (candidate) => recentSearchKey(candidate) === recentSearchKey(entry)
          ) === index
      )
      .slice(0, MAX_RECENT_SEARCHES);
  } catch {
    return [];
  }
}

function isRecentSearchStorage(value: unknown): value is RecentSearchStorage {
  if (!isRecord(value) || value.version !== RECENT_SEARCH_STORAGE_VERSION) return false;
  return Array.isArray(value.entries) && value.entries.every(isRecentSearchSnapshot);
}

function isRecentSearchSnapshot(value: unknown): value is RecentSearchSnapshot {
  if (!isRecord(value) || !isRecord(value.coordinate)) return false;
  if (
    typeof value.id !== 'string' ||
    typeof value.name !== 'string' ||
    !isCoordinate(value.coordinate)
  ) {
    return false;
  }

  if (value.kind === 'address') return typeof value.context === 'string';
  if (value.kind !== 'station' || !Array.isArray(value.routes)) return false;

  return value.routes.every(isRouteBadge);
}

function isCoordinate(value: Record<string, unknown>): value is Coordinate {
  return (
    typeof value.latitude === 'number' &&
    Number.isFinite(value.latitude) &&
    typeof value.longitude === 'number' &&
    Number.isFinite(value.longitude)
  );
}

function isRouteBadge(value: unknown): value is RouteBadge {
  if (!isRecord(value)) return false;
  return (
    typeof value.id === 'string' &&
    typeof value.shortName === 'string' &&
    (value.mode === 'metro' || value.mode === 'rer' || value.mode === 'bus') &&
    typeof value.color === 'string' &&
    typeof value.textColor === 'string'
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

import type { SearchResult } from '@via/contract';

import { distanceBetween } from '@/features/map/model/distance-between';
import type { UserLocationState } from '@/features/map/model/types';
import type { RecentSearchSnapshot } from '@/features/search/model/recent-searches';

export function distanceForResult(
  result: SearchResult | RecentSearchSnapshot,
  location: UserLocationState
) {
  const storedDistance = 'distanceMeters' in result ? result.distanceMeters : undefined;
  if (storedDistance !== undefined) return storedDistance;
  return location.status === 'ready'
    ? distanceBetween(location.coordinate, result.coordinate)
    : undefined;
}

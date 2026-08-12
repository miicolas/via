import type { Coordinate, NetworkRoute, NetworkStation, SearchResult } from '@via/contract';

import type { SearchState } from '@/features/home-map/model/search-state';
import type { NetworkState } from '@/lib/metro-network';

export type UserLocationState =
  | { status: 'loading' }
  | { status: 'denied' }
  | { status: 'error' }
  | {
      status: 'ready';
      coordinate: Coordinate;
      source: 'device' | 'development-default';
    };

export type StationFocus = {
  station: NetworkStation;
  coordinate: Coordinate;
  distanceMeters?: number;
};

/**
 * A picked address: name plus coordinate, which is exactly what a future
 * journey needs as its destination.
 */
export type SelectedPlace = {
  name: string;
  coordinate: Coordinate;
};

export type HomeMapValue = {
  activeRoutes: NetworkRoute[];
  activeStation?: StationFocus;
  isSearchActive: boolean;
  networkState: NetworkState;
  overviewDetentIndex: number;
  refreshLocation: () => Promise<void>;
  retryNetwork: () => void;
  search: SearchState;
  selectResult: (result: SearchResult) => void;
  selectStation: (stationId: string) => void;
  setOverviewDetentIndex: (index: number) => void;
  selectedPlace?: SelectedPlace;
  setSearchQuery: (query: string) => void;
  userLocation: UserLocationState;
};

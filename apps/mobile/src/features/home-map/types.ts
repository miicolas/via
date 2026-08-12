import type { Coordinate, NetworkRoute, NetworkStation } from '@via/contract';

import type { NetworkState } from '@/lib/metro-network';

export type UserLocationState =
  | { status: 'loading' }
  | { status: 'denied' }
  | { status: 'error' }
  | { status: 'ready'; coordinate: Coordinate };

export type StationFocus = {
  station: NetworkStation;
  coordinate: Coordinate;
  distanceMeters?: number;
};

export type HomeMapValue = {
  activeRoutes: NetworkRoute[];
  activeStation?: StationFocus;
  isSearchActive: boolean;
  networkState: NetworkState;
  refreshLocation: () => Promise<void>;
  retryNetwork: () => void;
  searchResults: NetworkStation[];
  selectStation: (stationId: string) => void;
  setSearchQuery: (query: string) => void;
  userLocation: UserLocationState;
};

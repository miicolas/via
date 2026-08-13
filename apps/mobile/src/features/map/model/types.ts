import type {
  Coordinate,
  Journey,
  JourneyDestination,
  NetworkRoute,
  NetworkStation,
  SearchResult,
} from '@via/contract';

import type { SearchState } from '@/features/search/model/state';
import type { FlowState } from '@/features/map/model/flow';
import type { JourneyState } from '@/features/journey/model/state';
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

export type SelectedDestination = JourneyDestination;

export type MapValue = {
  activeRoutes: NetworkRoute[];
  activeStation?: StationFocus;
  cancelJourney: () => void;
  flow: FlowState;
  isNearbyStation: boolean;
  isSearchActive: boolean;
  networkState: NetworkState;
  overviewDetentIndex: number;
  refreshLocation: () => Promise<void>;
  retryNetwork: () => void;
  searchQuery: string;
  search: SearchState;
  journey: JourneyState;
  journeyDestination?: SelectedDestination;
  journeyDistanceMeters?: number;
  selectedJourney?: Journey;
  selectedJourneyIndex: number;
  openJourneyDetail: (index: number) => void;
  closeJourneyDetail: () => void;
  retryJourney: () => void;
  selectResult: (result: SearchResult) => boolean;
  selectStation: (stationId: string) => void;
  setOverviewDetentIndex: (index: number) => void;
  selectedPlace?: SelectedPlace;
  setSearchQuery: (query: string) => void;
  userLocation: UserLocationState;
};

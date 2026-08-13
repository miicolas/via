import type {
  Coordinate,
  Journey,
  JourneyDestination,
  NetworkRoute,
  NetworkStation,
  SearchResult,
} from '@via/contract';

import type { SearchState } from '@/features/search/hooks/use-search';
import type { FlowScreen, MapFocusIntent } from '@/features/map/model/flow';
import type { JourneyState } from '@/features/journey/hooks/use-plan';
import type { NetworkState } from '@/hooks/use-metro-network';

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

export type MapValue = {
  activeRoutes: NetworkRoute[];
  activeStation?: StationFocus;
  cancelJourney: () => void;
  changeOverviewDetent: (index: number) => void;
  focusIntent?: MapFocusIntent;
  isNearbyStation: boolean;
  networkState: NetworkState;
  overviewDetentIndex: number;
  refreshLocation: () => Promise<void>;
  retryNetwork: () => void;
  searchQuery: string;
  search: SearchState;
  journey: JourneyState;
  journeyDestination?: JourneyDestination;
  journeyDistanceMeters?: number;
  screen: FlowScreen;
  selectedJourney?: Journey;
  selectedJourneyIndex: number;
  openJourneyDetail: (index: number) => void;
  closeJourneyDetail: () => void;
  retryJourney: () => void;
  selectResult: (result: SearchResult) => boolean;
  selectStation: (stationId: string, focusCoordinate?: Coordinate) => void;
  setSearchQuery: (query: string) => void;
  userLocation: UserLocationState;
};

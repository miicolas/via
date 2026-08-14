import type {
  Coordinate,
  Journey,
  JourneyDestination,
  JourneysResponse,
  NetworkStation,
  RouteBadge,
  SearchResult,
} from '@via/contract';

import type { ViewportRegion } from '@/lib/viewport-tiles';

import type { SearchState } from '@/features/search/hooks/use-search';
import type { RecentSearchesState } from '@/features/search/hooks/use-recent-searches';
import type { RecentSearchSnapshot } from '@/features/search/model/recent-searches';
import type { NaturalJourneyChoice } from '@/features/journey/model/clarification-choice';
import type { FlowScreen, MapFocusIntent } from '@/features/map/model/flow';
import type { JourneyState } from '@/features/journey/hooks/use-plan';
import type { NaturalJourneyState } from '@/features/journey/hooks/use-natural-journey';
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
  activeStation?: StationFocus;
  cancelJourney: () => void;
  changeOverviewDetent: (index: number) => void;
  focusIntent?: MapFocusIntent;
  isNearbyStation: boolean;
  /** Rail stations merged with whatever the viewport tiles have loaded. */
  mapStations: NetworkStation[];
  networkState: NetworkState;
  overviewDetentIndex: number;
  refreshLocation: () => Promise<void>;
  /** Tells the tile loader what the user currently sees. */
  reportViewport: (region: ViewportRegion) => void;
  retryNetwork: () => void;
  recentSearches: RecentSearchesState;
  /** Badges for every route `mapStations` can reference, rail and bus alike. */
  stationRoutes: RouteBadge[];
  searchQuery: string;
  searchFocused: boolean;
  search: SearchState;
  journey: JourneyState;
  naturalJourney: NaturalJourneyState;
  journeyDestination?: JourneyDestination;
  journeyDistanceMeters?: number;
  screen: FlowScreen;
  selectedJourney?: Journey;
  selectedJourneyIndex: number;
  openJourneyDetail: (index: number) => void;
  closeJourneyDetail: () => void;
  retryJourney: () => void;
  submitNaturalJourney: () => void;
  /** Shows an already-computed itinerary (the chat's answer) in the journey flow. */
  startViaJourney: (destination: JourneyDestination, response: JourneysResponse) => void;
  resolveNaturalJourney: (choice: NaturalJourneyChoice) => void;
  selectResult: (result: SearchResult | RecentSearchSnapshot) => boolean;
  selectStation: (stationId: string, focusCoordinate?: Coordinate) => void;
  setSearchQuery: (query: string) => void;
  setSearchFocused: (focused: boolean) => void;
  userLocation: UserLocationState;
};

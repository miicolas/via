import type { PropsWithChildren } from 'react';
import { useCallback, useDeferredValue, useEffect, useMemo, useReducer } from 'react';
import type {
  Coordinate,
  JourneyDestination,
  JourneysResponse,
  RouteBadge,
  SearchResult,
} from '@via/contract';

import { nearestStation } from '@/features/map/model/nearest-station';
import { INITIAL_MAP_FLOW, transitionMapFlow } from '@/features/map/model/flow';
import { mergeStations } from '@/features/map/model/merge-stations';
import { isNearbyDistance } from '@/features/map/model/nearby-distance';
import { useAreaStations } from '@/features/map/hooks/use-area-stations';
import { useSearch } from '@/features/search/hooks/use-search';
import { useRecentSearches } from '@/features/search/hooks/use-recent-searches';
import type { RecentSearchSnapshot } from '@/features/search/model/recent-searches';
import { distanceForResult } from '@/features/search/model/result-distance';
import { useJourneySource } from '@/features/journey/hooks/use-journey-source';
import { useNaturalJourneyFlow } from '@/features/journey/hooks/use-natural-journey-flow';
import { useUserLocation } from '@/features/map/hooks/use-location';
import { MapContext } from '@/features/map/state/context';
import { useMetroNetwork } from '@/hooks/use-metro-network';

export function MapProvider({ children }: PropsWithChildren) {
  const metro = useMetroNetwork();
  const area = useAreaStations();
  const location = useUserLocation();
  const [flow, dispatchFlow] = useReducer(transitionMapFlow, INITIAL_MAP_FLOW);
  const deferredQuery = useDeferredValue(flow.searchQuery);
  const recentSearches = useRecentSearches();
  const naturalJourney = useNaturalJourneyFlow({
    query: flow.searchQuery,
    location: location.state,
    dispatch: dispatchFlow,
    rememberDestination: recentSearches.remember,
  });

  const railStations = metro.network?.stations;
  const stations = useMemo(
    () => (railStations ? mergeStations(railStations, area.stations) : undefined),
    [area.stations, railStations]
  );
  const stationRoutes = useMemo<RouteBadge[]>(() => {
    const byId = new Map<string, RouteBadge>();
    for (const route of metro.network?.routes ?? []) byId.set(route.id, route);
    for (const route of area.routes) if (!byId.has(route.id)) byId.set(route.id, route);
    return [...byId.values()];
  }, [area.routes, metro.network?.routes]);

  useEffect(() => {
    if (location.state.status === 'ready') area.ensureArea(location.state.coordinate);
  }, [area.ensureArea, location.state]);

  const closestStation = useMemo(() => {
    if (location.state.status !== 'ready' || !stations) return undefined;
    const closest = nearestStation(stations, location.state.coordinate);
    return closest && isNearbyDistance(closest.distanceMeters) ? closest : undefined;
  }, [location.state, stations]);

  const selectedStation = useMemo(() => {
    if (!flow.selectedStationId) return undefined;
    const station = stations?.find(({ id }) => id === flow.selectedStationId);
    if (!station) return undefined;
    const distanceMeters =
      location.state.status === 'ready'
        ? nearestStation([station], location.state.coordinate)?.distanceMeters
        : undefined;
    return { station, coordinate: station.coordinate, distanceMeters };
  }, [flow.selectedStationId, location.state, stations]);

  const activeStation = selectedStation ?? closestStation;
  const search = useSearch(deferredQuery, location.state);
  const isNearbyStation = isNearbyDistance(activeStation?.distanceMeters);
  const journeySource = useJourneySource({
    destination: flow.journeyDestination,
    retryGeneration: flow.journeyRetry,
    location: location.state,
    naturalJourney: naturalJourney.state,
  });
  const journey = journeySource.journey;
  const startViaJourney = useCallback(
    (destination: JourneyDestination, response: JourneysResponse) => {
      journeySource.inject(destination, response);
      dispatchFlow({ type: 'natural-journey-ready', destination });
      dispatchFlow({ type: 'journey-detail-opened', index: 0 });
    },
    [journeySource.inject]
  );
  const selectedJourney =
    journey.status === 'ready'
      ? journey.response.journeys[flow.selectedJourneyIndex]
      : undefined;

  useEffect(() => {
    if (
      flow.screen === 'planning' &&
      (journey.status === 'ready' || journey.status === 'error')
    ) {
      dispatchFlow({ type: 'planning-settled' });
    }
  }, [flow.screen, journey.status]);

  useEffect(() => {
    if (!activeStation) return;
    dispatchFlow({
      type: 'station-focus-available',
      stationId: activeStation.station.id,
      coordinate: activeStation.coordinate,
    });
  }, [activeStation]);

  useEffect(() => {
    if ((flow.screen !== 'results' && flow.screen !== 'detail') || !selectedJourney) return;
    dispatchFlow({ type: 'journey-focus-available', journey: selectedJourney });
  }, [flow.screen, selectedJourney]);

  const setSearchQuery = useCallback((value: string) => {
    naturalJourney.clear();
    dispatchFlow({ type: 'query-changed', query: value });
  }, [naturalJourney.clear]);
  const setSearchFocused = useCallback((focused: boolean) => {
    dispatchFlow({ type: 'search-focus-changed', focused });
  }, []);
  const resolveStationJourney = useCallback(
    (stationId: string) => {
      const station = stations?.find(({ id }) => id === stationId);
      if (!station) return {};
      const distanceMeters =
        location.state.status === 'ready'
          ? nearestStation([station], location.state.coordinate)?.distanceMeters
          : undefined;
      if (isNearbyDistance(distanceMeters)) return {};
      return {
        journeyDestination: {
          kind: 'station' as const,
          id: station.id,
          name: station.name,
          coordinate: station.coordinate,
        },
        journeyDistanceMeters: distanceMeters,
      };
    },
    [location.state, stations]
  );
  const selectStation = useCallback(
    (stationId: string, focusCoordinate?: Coordinate) => {
      dispatchFlow({
        type: 'station-selected',
        stationId,
        focusCoordinate,
        ...resolveStationJourney(stationId),
      });
    },
    [resolveStationJourney]
  );
  const selectResult = useCallback(
    (result: SearchResult | RecentSearchSnapshot) => {
      naturalJourney.clear();
      recentSearches.remember(result);
      const distanceMeters = distanceForResult(result, location.state);

      if (result.kind === 'station') {
        const journeySelection = isNearbyDistance(distanceMeters)
          ? {}
          : {
              journeyDestination: {
                kind: 'station' as const,
                id: result.id,
                name: result.name,
                coordinate: result.coordinate,
              },
              journeyDistanceMeters: distanceMeters,
            };
        dispatchFlow({ type: 'station-selected', stationId: result.id, ...journeySelection });
        return journeySelection.journeyDestination !== undefined;
      }

      const journeyDestination: JourneyDestination = {
        kind: 'address',
        id: result.id,
        name: result.name,
        context: result.context,
        coordinate: result.coordinate,
      };
      dispatchFlow({
        type: 'address-selected',
        place: { name: result.name, coordinate: result.coordinate },
        journeyDestination,
        journeyDistanceMeters: distanceMeters,
      });
      return true;
    },
    [location.state, naturalJourney.clear, recentSearches]
  );

  const openJourneyDetail = useCallback((index: number) => {
    dispatchFlow({ type: 'journey-detail-opened', index });
  }, []);
  const closeJourneyDetail = useCallback(() => {
    dispatchFlow({ type: 'journey-detail-closed' });
  }, []);
  const retryJourney = useCallback(() => {
    // A retry always recomputes: an injected itinerary cannot be re-run, only replanned.
    journeySource.clearInjected();
    dispatchFlow({ type: 'journey-retried' });
  }, [journeySource.clearInjected]);
  const cancelJourney = useCallback(() => {
    naturalJourney.clear();
    journeySource.clearInjected();
    dispatchFlow({ type: 'journey-cancelled' });
  }, [journeySource.clearInjected, naturalJourney.clear]);
  const changeOverviewDetent = useCallback((index: number) => {
    dispatchFlow({ type: 'detent-changed', index });
  }, []);

  const value = useMemo(
    () => ({
      activeStation,
      cancelJourney,
      changeOverviewDetent,
      focusIntent: flow.focusIntent,
      isNearbyStation,
      journey,
      naturalJourney: naturalJourney.state,
      journeyDestination: flow.journeyDestination,
      journeyDistanceMeters: flow.journeyDistanceMeters,
      mapStations: stations ?? [],
      networkState: metro.state,
      openJourneyDetail,
      overviewDetentIndex: flow.overviewDetentIndex,
      recentSearches,
      refreshLocation: location.refresh,
      reportViewport: area.reportViewport,
      retryNetwork: metro.retry,
      screen: flow.screen,
      searchFocused: flow.searchFocused,
      searchQuery: flow.searchQuery,
      search,
      selectedJourney,
      selectedJourneyIndex: flow.selectedJourneyIndex,
      selectResult,
      selectStation,
      stationRoutes,
      closeJourneyDetail,
      retryJourney,
      resolveNaturalJourney: naturalJourney.resolve,
      setSearchFocused,
      setSearchQuery,
      startViaJourney,
      submitNaturalJourney: naturalJourney.submit,
      userLocation: location.state,
    }),
    [
      activeStation,
      area.reportViewport,
      cancelJourney,
      changeOverviewDetent,
      closeJourneyDetail,
      flow.focusIntent,
      flow.screen,
      flow.searchFocused,
      isNearbyStation,
      journey,
      naturalJourney.state,
      flow.journeyDestination,
      flow.journeyDistanceMeters,
      flow.overviewDetentIndex,
      flow.searchQuery,
      flow.selectedJourneyIndex,
      location.refresh,
      location.state,
      metro.retry,
      metro.state,
      openJourneyDetail,
      search,
      selectedJourney,
      selectResult,
      selectStation,
      stations,
      stationRoutes,
      retryJourney,
      setSearchFocused,
      setSearchQuery,
      startViaJourney,
      recentSearches,
      naturalJourney.resolve,
      naturalJourney.submit,
    ]
  );

  return <MapContext value={value}>{children}</MapContext>;
}

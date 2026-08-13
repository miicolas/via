import type { PropsWithChildren } from 'react';
import { useCallback, useDeferredValue, useEffect, useMemo, useReducer, useState } from 'react';
import type { JourneyDestination, NetworkRoute, SearchResult } from '@via/contract';

import { nearestStation } from '@/features/home-map/model/nearest-station';
import {
  MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
} from '@/features/home-map/model/overview-sheet';
import { homeFlowReducer, INITIAL_HOME_FLOW } from '@/features/home-map/model/home-flow';
import { routesForStation } from '@/features/home-map/model/routes-for-station';
import { isNearbyDistance } from '@/features/home-map/model/nearby-distance';
import type { SelectedPlace } from '@/features/home-map/model/types';
import { useSearch } from '@/features/home-map/hooks/use-search';
import { useJourneyPlan } from '@/features/home-map/hooks/use-journey-plan';
import { useUserLocation } from '@/features/home-map/hooks/use-location';
import { HomeMapContext } from '@/features/home-map/state/context';
import { journeyRequestKey, type JourneyRequest } from '@/features/home-map/model/journey-state';
import { useMetroNetwork } from '@/hooks/use-metro-network';
import { stationCoordinate } from '@/lib/metro-network';

const EMPTY_ROUTES: NetworkRoute[] = [];

export function HomeMapProvider({ children }: PropsWithChildren) {
  const metro = useMetroNetwork();
  const location = useUserLocation();
  const [query, setQuery] = useState('');
  const deferredQuery = useDeferredValue(query);
  const [overviewDetentIndex, setOverviewDetentIndex] = useState(
    MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX
  );
  const [selectedStationId, setSelectedStationId] = useState<string>();
  const [selectedPlace, setSelectedPlace] = useState<SelectedPlace>();
  const [journeyDestination, setJourneyDestination] = useState<JourneyDestination>();
  const [journeyDistanceMeters, setJourneyDistanceMeters] = useState<number>();
  const [journeyRetry, setJourneyRetry] = useState(0);
  const [flow, dispatchFlow] = useReducer(homeFlowReducer, INITIAL_HOME_FLOW);

  const stations = metro.network?.stations;
  const routes = metro.state.status === 'ready' ? metro.state.lines : EMPTY_ROUTES;
  const closestStation = useMemo(() => {
    if (location.state.status !== 'ready' || !stations) return undefined;
    const closest = nearestStation(stations, location.state.coordinate);
    return closest && isNearbyDistance(closest.distanceMeters) ? closest : undefined;
  }, [location.state, stations]);

  const selectedStation = useMemo(() => {
    if (!selectedStationId) return undefined;
    const station = stations?.find(({ id }) => id === selectedStationId);
    const coordinate = station && stationCoordinate(station);
    if (!station || !coordinate) return undefined;
    const distanceMeters =
      location.state.status === 'ready'
        ? nearestStation([station], location.state.coordinate)?.distanceMeters
        : undefined;
    return { station, coordinate, distanceMeters };
  }, [location.state, selectedStationId, stations]);

  const activeStation = selectedStation ?? closestStation;
  const search = useSearch(deferredQuery, location.state);
  const activeRoutes = useMemo(
    () => routesForStation(routes, activeStation?.station),
    [activeStation?.station, routes]
  );
  const isNearbyStation = isNearbyDistance(activeStation?.distanceMeters);
  const journeyRequest = useMemo<JourneyRequest | undefined>(() => {
    if (!journeyDestination || location.state.status !== 'ready') return undefined;
    return {
      key: journeyRequestKey(location.state.coordinate, journeyDestination, journeyRetry),
      origin: location.state.coordinate,
      destination: journeyDestination,
    };
  }, [journeyDestination, journeyRetry, location.state]);
  const journey = useJourneyPlan(journeyRequest);
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

  const setSearchQuery = useCallback((value: string) => {
    setQuery(value);
    setSelectedStationId(undefined);
    setSelectedPlace(undefined);
    setJourneyDestination(undefined);
    setJourneyDistanceMeters(undefined);
    dispatchFlow({ type: 'query-changed', hasQuery: value.trim().length > 0 });
  }, []);
  const setStationDestination = useCallback(
    (stationId: string) => {
      const station = stations?.find(({ id }) => id === stationId);
      const coordinate = station && stationCoordinate(station);
      if (!station || !coordinate) return false;
      const distanceMeters =
        location.state.status === 'ready'
          ? nearestStation([station], location.state.coordinate)?.distanceMeters
          : undefined;
      if (isNearbyDistance(distanceMeters)) {
        setJourneyDestination(undefined);
        setJourneyDistanceMeters(undefined);
        return false;
      } else {
        setJourneyDestination({ kind: 'station', id: station.id, name: station.name, coordinate });
        setJourneyDistanceMeters(distanceMeters);
        return true;
      }
    },
    [location.state, stations]
  );
  const selectStation = useCallback((stationId: string) => {
    setSelectedStationId(stationId);
    setSelectedPlace(undefined);
    const plansJourney = setStationDestination(stationId);
    dispatchFlow({ type: plansJourney ? 'destination-selected' : 'nearby-selected' });
    setOverviewDetentIndex(
      plansJourney
        ? MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX
        : MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX
    );
  }, [setStationDestination]);
  const selectResult = useCallback((result: SearchResult) => {
    let plansJourney = false;
    if (result.kind === 'station') {
      setSelectedStationId(result.id);
      setSelectedPlace(undefined);
      plansJourney = setStationDestination(result.id);
    } else {
      setSelectedStationId(undefined);
      setSelectedPlace({ name: result.name, coordinate: result.coordinate });
      setJourneyDestination({
        kind: 'address',
        id: result.id,
        name: result.name,
        context: result.context,
        coordinate: result.coordinate,
      });
      setJourneyDistanceMeters(result.distanceMeters);
      plansJourney = true;
    }
    dispatchFlow({ type: plansJourney ? 'destination-selected' : 'nearby-selected' });
    setOverviewDetentIndex(
      plansJourney
        ? MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX
        : MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX
    );
    return plansJourney;
  }, [setStationDestination]);

  const openJourneyDetail = useCallback((index: number) => {
    dispatchFlow({ type: 'open-detail', index });
    setOverviewDetentIndex(MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX);
  }, []);
  const closeJourneyDetail = useCallback(() => {
    dispatchFlow({ type: 'close-detail' });
    setOverviewDetentIndex(MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX);
  }, []);
  const retryJourney = useCallback(() => {
    setJourneyRetry((retry) => retry + 1);
    dispatchFlow({ type: 'retry-planning' });
    setOverviewDetentIndex(MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX);
  }, []);
  const cancelJourney = useCallback(() => {
    setSelectedStationId(undefined);
    setSelectedPlace(undefined);
    setJourneyDestination(undefined);
    setJourneyDistanceMeters(undefined);
    dispatchFlow({ type: 'cancel-journey', hasQuery: query.trim().length > 0 });
    setOverviewDetentIndex(
      query.trim().length > 0
        ? MAP_OVERVIEW_SHEET_EXPANDED_DETENT_INDEX
        : MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX
    );
  }, [query]);

  const value = useMemo(
    () => ({
      activeRoutes,
      activeStation,
      cancelJourney,
      flow,
      isNearbyStation,
      isSearchActive: flow.screen === 'search',
      journey,
      journeyDestination,
      journeyDistanceMeters,
      networkState: metro.state,
      openJourneyDetail,
      overviewDetentIndex,
      refreshLocation: location.refresh,
      retryNetwork: metro.retry,
      searchQuery: query,
      search,
      selectedJourney,
      selectedJourneyIndex: flow.selectedJourneyIndex,
      selectResult,
      selectStation,
      selectedPlace,
      closeJourneyDetail,
      retryJourney,
      setOverviewDetentIndex,
      setSearchQuery,
      userLocation: location.state,
    }),
    [
      activeRoutes,
      activeStation,
      cancelJourney,
      closeJourneyDetail,
      flow,
      isNearbyStation,
      journey,
      journeyDistanceMeters,
      location.refresh,
      location.state,
      metro.retry,
      metro.state,
      openJourneyDetail,
      overviewDetentIndex,
      search,
      selectedJourney,
      selectResult,
      selectStation,
      selectedPlace,
      retryJourney,
      query,
      setSearchQuery,
      journeyDestination,
    ]
  );

  return <HomeMapContext value={value}>{children}</HomeMapContext>;
}

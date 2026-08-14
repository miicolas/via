import type { PropsWithChildren } from 'react';
import { useCallback, useDeferredValue, useEffect, useMemo, useReducer } from 'react';
import type { Coordinate, JourneyDestination, RouteBadge, SearchResult } from '@via/contract';

import { nearestStation } from '@/features/map/model/nearest-station';
import { INITIAL_MAP_FLOW, transitionMapFlow } from '@/features/map/model/flow';
import { mergeStations } from '@/features/map/model/merge-stations';
import { isNearbyDistance } from '@/features/map/model/nearby-distance';
import { useAreaStations } from '@/features/map/hooks/use-area-stations';
import { useSearch } from '@/features/search/hooks/use-search';
import { useJourneyPlan } from '@/features/journey/hooks/use-plan';
import { useUserLocation } from '@/features/map/hooks/use-location';
import { MapContext } from '@/features/map/state/context';
import { journeyRequestKey, type JourneyRequest } from '@/features/journey/model/request';
import { useMetroNetwork } from '@/hooks/use-metro-network';

export function MapProvider({ children }: PropsWithChildren) {
  const metro = useMetroNetwork();
  const area = useAreaStations();
  const location = useUserLocation();
  const [flow, dispatchFlow] = useReducer(transitionMapFlow, INITIAL_MAP_FLOW);
  const deferredQuery = useDeferredValue(flow.searchQuery);

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

  // The nearest-station lookup needs the stops around the user — including bus
  // stops the viewport may never have visited — so their tiles load eagerly.
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
  const journeyRequest = useMemo<JourneyRequest | undefined>(() => {
    if (!flow.journeyDestination || location.state.status !== 'ready') return undefined;
    return {
      key: journeyRequestKey(
        location.state.coordinate,
        flow.journeyDestination,
        flow.journeyRetry
      ),
      origin: location.state.coordinate,
      destination: flow.journeyDestination,
    };
  }, [flow.journeyDestination, flow.journeyRetry, location.state]);
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

  useEffect(() => {
    if (!activeStation) return;
    dispatchFlow({
      type: 'station-focus-available',
      stationId: activeStation.station.id,
      coordinate: activeStation.coordinate,
    });
  }, [activeStation]);

  useEffect(() => {
    if (flow.screen !== 'detail' || !selectedJourney) return;
    dispatchFlow({ type: 'journey-focus-available', journey: selectedJourney });
  }, [flow.screen, selectedJourney]);

  const setSearchQuery = useCallback((value: string) => {
    dispatchFlow({ type: 'query-changed', query: value });
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
    (result: SearchResult) => {
      if (result.kind === 'station') {
        // From its own payload, not the loaded stations: a searched bus stop
        // across town sits in no visited viewport tile, yet its result already
        // carries the coordinate and distance the journey needs.
        const journeySelection = isNearbyDistance(result.distanceMeters)
          ? {}
          : {
              journeyDestination: {
                kind: 'station' as const,
                id: result.id,
                name: result.name,
                coordinate: result.coordinate,
              },
              journeyDistanceMeters: result.distanceMeters,
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
        journeyDistanceMeters: result.distanceMeters,
      });
      return true;
    },
    [resolveStationJourney]
  );

  const openJourneyDetail = useCallback((index: number) => {
    dispatchFlow({ type: 'journey-detail-opened', index });
  }, []);
  const closeJourneyDetail = useCallback(() => {
    dispatchFlow({ type: 'journey-detail-closed' });
  }, []);
  const retryJourney = useCallback(() => {
    dispatchFlow({ type: 'journey-retried' });
  }, []);
  const cancelJourney = useCallback(() => {
    dispatchFlow({ type: 'journey-cancelled' });
  }, []);
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
      journeyDestination: flow.journeyDestination,
      journeyDistanceMeters: flow.journeyDistanceMeters,
      mapStations: stations ?? [],
      networkState: metro.state,
      openJourneyDetail,
      overviewDetentIndex: flow.overviewDetentIndex,
      refreshLocation: location.refresh,
      reportViewport: area.reportViewport,
      retryNetwork: metro.retry,
      screen: flow.screen,
      searchQuery: flow.searchQuery,
      search,
      selectedJourney,
      selectedJourneyIndex: flow.selectedJourneyIndex,
      selectResult,
      selectStation,
      stationRoutes,
      closeJourneyDetail,
      retryJourney,
      setSearchQuery,
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
      isNearbyStation,
      journey,
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
      setSearchQuery,
    ]
  );

  return <MapContext value={value}>{children}</MapContext>;
}

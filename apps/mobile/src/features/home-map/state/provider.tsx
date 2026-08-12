import type { PropsWithChildren } from 'react';
import { useCallback, useDeferredValue, useMemo, useState } from 'react';
import type { NetworkRoute, SearchResult } from '@via/contract';

import { nearestStation } from '@/features/home-map/model/nearest-station';
import { MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX } from '@/features/home-map/model/overview-sheet';
import { routesForStation } from '@/features/home-map/model/routes-for-station';
import type { SelectedPlace } from '@/features/home-map/model/types';
import { useSearch } from '@/features/home-map/hooks/use-search';
import { useUserLocation } from '@/features/home-map/hooks/use-location';
import { HomeMapContext } from '@/features/home-map/state/context';
import { useMetroNetwork } from '@/hooks/use-metro-network';
import { stationCoordinate } from '@/lib/metro-network';

const MAX_NEARBY_DISTANCE_METERS = 3_000;
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

  const stations = metro.network?.stations;
  const routes = metro.state.status === 'ready' ? metro.state.lines : EMPTY_ROUTES;
  const closestStation = useMemo(() => {
    if (location.state.status !== 'ready' || !stations) return undefined;
    const closest = nearestStation(stations, location.state.coordinate);
    return closest && (closest.distanceMeters ?? Infinity) <= MAX_NEARBY_DISTANCE_METERS
      ? closest
      : undefined;
  }, [location.state, stations]);

  const selectedStation = useMemo(() => {
    if (!selectedStationId) return undefined;
    const station = stations?.find(({ id }) => id === selectedStationId);
    const coordinate = station && stationCoordinate(station);
    return station && coordinate ? { station, coordinate } : undefined;
  }, [selectedStationId, stations]);

  const activeStation = selectedStation ?? closestStation;
  const search = useSearch(deferredQuery, location.state);
  const activeRoutes = useMemo(
    () => routesForStation(routes, activeStation?.station),
    [activeStation?.station, routes]
  );

  const setSearchQuery = useCallback((value: string) => {
    setQuery(value);
    setSelectedStationId(undefined);
    setSelectedPlace(undefined);
  }, []);
  const selectStation = useCallback((stationId: string) => setSelectedStationId(stationId), []);
  const selectResult = useCallback((result: SearchResult) => {
    if (result.kind === 'station') setSelectedStationId(result.id);
    else setSelectedPlace({ name: result.name, coordinate: result.coordinate });
  }, []);

  const value = useMemo(
    () => ({
      activeRoutes,
      activeStation,
      isSearchActive: deferredQuery.trim().length > 0 && !selectedStation && !selectedPlace,
      networkState: metro.state,
      overviewDetentIndex,
      refreshLocation: location.refresh,
      retryNetwork: metro.retry,
      search,
      selectResult,
      selectStation,
      selectedPlace,
      setOverviewDetentIndex,
      setSearchQuery,
      userLocation: location.state,
    }),
    [
      activeRoutes,
      activeStation,
      deferredQuery,
      location.refresh,
      location.state,
      metro.retry,
      metro.state,
      overviewDetentIndex,
      search,
      selectResult,
      selectStation,
      selectedPlace,
      selectedStation,
      setSearchQuery,
    ]
  );

  return <HomeMapContext value={value}>{children}</HomeMapContext>;
}

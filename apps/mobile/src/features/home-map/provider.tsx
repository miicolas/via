import type { PropsWithChildren } from 'react';
import { useCallback, useDeferredValue, useMemo, useState } from 'react';
import type { NetworkRoute, NetworkStation } from '@via/contract';

import { HomeMapContext } from '@/features/home-map/context';
import { nearestStation } from '@/features/home-map/nearest-station';
import { routesForStation } from '@/features/home-map/routes-for-station';
import { searchStations } from '@/features/home-map/search-stations';
import { stationCoordinate } from '@/features/home-map/station-coordinate';
import { useUserLocation } from '@/features/home-map/use-location';
import { useMetroNetwork } from '@/hooks/use-metro-network';

const MAX_NEARBY_DISTANCE_METERS = 3_000;
const EMPTY_ROUTES: NetworkRoute[] = [];
const EMPTY_STATIONS: NetworkStation[] = [];

export function HomeMapProvider({ children }: PropsWithChildren) {
  const metro = useMetroNetwork();
  const location = useUserLocation();
  const [query, setQuery] = useState('');
  const deferredQuery = useDeferredValue(query);
  const [selectedStationId, setSelectedStationId] = useState<string>();

  const stations = metro.network?.stations ?? EMPTY_STATIONS;
  const routes = metro.state.status === 'ready' ? metro.state.lines : EMPTY_ROUTES;
  const closestStation = useMemo(() => {
    if (location.state.status !== 'ready') return undefined;
    const closest = nearestStation(stations, location.state.coordinate);
    return closest && (closest.distanceMeters ?? Infinity) <= MAX_NEARBY_DISTANCE_METERS
      ? closest
      : undefined;
  }, [location.state, stations]);

  const selectedStation = useMemo(() => {
    if (!selectedStationId) return undefined;
    const station = stations.find(({ id }) => id === selectedStationId);
    const coordinate = station && stationCoordinate(station);
    return station && coordinate ? { station, coordinate } : undefined;
  }, [selectedStationId, stations]);

  const activeStation = selectedStation ?? closestStation;
  const searchResults = useMemo(
    () => searchStations(stations, deferredQuery),
    [deferredQuery, stations]
  );
  const activeRoutes = useMemo(
    () => routesForStation(routes, activeStation?.station),
    [activeStation?.station, routes]
  );

  const setSearchQuery = useCallback((value: string) => {
    setQuery(value);
    setSelectedStationId(undefined);
  }, []);
  const selectStation = useCallback((stationId: string) => setSelectedStationId(stationId), []);

  const value = useMemo(
    () => ({
      activeRoutes,
      activeStation,
      isSearchActive: deferredQuery.trim().length > 0 && !selectedStation,
      networkState: metro.state,
      refreshLocation: location.refresh,
      retryNetwork: metro.retry,
      searchResults,
      selectStation,
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
      searchResults,
      selectStation,
      selectedStation,
      setSearchQuery,
    ]
  );

  return <HomeMapContext value={value}>{children}</HomeMapContext>;
}

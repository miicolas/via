import { useCallback, useEffect, useImperativeHandle, useRef, useState, type Ref } from 'react';
import { Animated, StyleSheet } from 'react-native';
import MapView, { type EdgePadding, type Region } from 'react-native-maps';

import { RouteLines } from '@/components/map/route-lines';
import { StationMarkers } from '@/components/map/station-markers';
import {
  PLACEHOLDER_ROUTE_COLOR,
  routeBounds,
  type NetworkRoute,
  type RouteStation,
} from '@/lib/network-map';

const INITIAL_REGION: Region = {
  latitude: 48.8683,
  longitude: 2.338,
  latitudeDelta: 0.13,
  longitudeDelta: 0.29,
};
/** Stations are hidden above this zoom-out level and fully opaque below the fade-in one. */
const STATION_FADE_OUT_DELTA = 0.14;
const STATION_FADE_IN_DELTA = 0.06;

export type MetroMapHandle = {
  fitSelectedRoute: (animated?: boolean) => void;
};

type MetroMapProps = {
  routes: NetworkRoute[];
  selectedRoute: NetworkRoute | undefined;
  stations: RouteStation[];
  /** Room the caller's overlay needs around the fitted line. */
  edgePadding: EdgePadding;
  ref?: Ref<MetroMapHandle>;
};

export function MetroMap({
  routes,
  selectedRoute,
  stations,
  edgePadding,
  ref,
}: MetroMapProps) {
  const mapRef = useRef<MapView>(null);
  const lastFittedRouteId = useRef<string | undefined>(undefined);
  const [stationOpacity] = useState(() => new Animated.Value(0));
  const [mapReady, setMapReady] = useState(false);

  const fitSelectedRoute = useCallback(
    (animated = true) => {
      const bounds = routeBounds(selectedRoute);
      if (bounds.length === 0) return;
      mapRef.current?.fitToCoordinates(bounds, { animated, edgePadding });
    },
    [edgePadding, selectedRoute]
  );

  useImperativeHandle(ref, () => ({ fitSelectedRoute }), [fitSelectedRoute]);

  // Frame the line on first render and whenever the selection changes, never twice for the same one.
  useEffect(() => {
    if (!mapReady || !selectedRoute) return;
    if (lastFittedRouteId.current === selectedRoute.id) return;
    const animated = lastFittedRouteId.current !== undefined;
    lastFittedRouteId.current = selectedRoute.id;
    requestAnimationFrame(() => fitSelectedRoute(animated));
  }, [fitSelectedRoute, mapReady, selectedRoute]);

  return (
    <MapView
      ref={mapRef}
      style={styles.map}
      initialRegion={INITIAL_REGION}
      mapType="standard"
      loadingEnabled
      loadingBackgroundColor="#F5F4EF"
      loadingIndicatorColor="#1D1D1F"
      pitchEnabled={false}
      rotateEnabled={false}
      showsBuildings
      showsCompass={false}
      showsIndoors={false}
      showsPointsOfInterests={false}
      showsTraffic={false}
      showsUserLocation={false}
      onMapReady={() => setMapReady(true)}
      onRegionChange={(region) => stationOpacity.setValue(fadeProgress(region.longitudeDelta))}
    >
      <RouteLines routes={routes} selectedRoute={selectedRoute} />
      <StationMarkers
        stations={stations}
        color={selectedRoute?.color ?? PLACEHOLDER_ROUTE_COLOR}
        opacity={stationOpacity}
      />
    </MapView>
  );
}

/** 0 when zoomed out past the fade-out level, 1 once past the fade-in one. */
function fadeProgress(longitudeDelta: number) {
  const progress =
    (STATION_FADE_OUT_DELTA - longitudeDelta) / (STATION_FADE_OUT_DELTA - STATION_FADE_IN_DELTA);
  return Math.max(0, Math.min(1, progress));
}

const styles = StyleSheet.create({
  map: { flex: 1 },
});

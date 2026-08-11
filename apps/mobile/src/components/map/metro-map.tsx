import type { NetworkRoute } from '@via/contract';
import { useImperativeHandle, useRef, useState, type Ref } from 'react';
import { Animated, StyleSheet } from 'react-native';
import MapView, { type EdgePadding, type Region } from 'react-native-maps';

import { RouteLines } from '@/components/map/route-lines';
import { StationMarkers } from '@/components/map/station-markers';
import { routeBounds, type LineView } from '@/lib/metro-network';

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
  /**
   * Frames a line's full extent. The caller decides *when*; this only knows how.
   * It takes the route rather than the `LineView` because framing needs the
   * track and nothing else — passing the whole view would invite handing it one
   * line's stations with another line's geometry.
   */
  fitToRoute: (route: NetworkRoute, options?: { animated?: boolean }) => void;
};

type MetroMapProps = {
  /** The whole network, drawn muted underneath. */
  lines: NetworkRoute[];
  /** The line in focus, with its stations. Absent until the network has loaded. */
  line: LineView | undefined;
  /** Room the caller's overlay needs around a fitted line. */
  edgePadding: EdgePadding;
  /** Fires once the native map can accept a camera command. */
  onReady: () => void;
  ref?: Ref<MetroMapHandle>;
};

/**
 * Draws the network and moves the camera when told to.
 *
 * It deliberately does not decide *when* to frame a line. That used to live here
 * as an effect plus a `lastFittedRouteId` sentinel, whose only job was to work
 * out whether a render meant "the user picked a new line" — a question the screen
 * can answer for free, because the screen is what handles the tap. One action now
 * has one trigger path, and reading the screen tells you that touching a line
 * moves the camera.
 */
export function MetroMap({ lines, line, edgePadding, onReady, ref }: MetroMapProps) {
  const mapRef = useRef<MapView>(null);
  const [stationOpacity] = useState(() => new Animated.Value(0));

  useImperativeHandle(
    ref,
    () => ({
      fitToRoute(route, { animated = true } = {}) {
        const bounds = routeBounds(route);
        if (bounds.length === 0) return;
        mapRef.current?.fitToCoordinates(bounds, { animated, edgePadding });
      },
    }),
    [edgePadding]
  );

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
      onMapReady={onReady}
      onRegionChange={(region) => stationOpacity.setValue(fadeProgress(region.longitudeDelta))}
    >
      <RouteLines routes={lines} selectedRoute={line?.route} />
      {line && <StationMarkers line={line} opacity={stationOpacity} />}
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

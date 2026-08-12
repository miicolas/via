import type { Coordinate, NetworkRoute, NetworkStation } from '@via/contract';
import { useImperativeHandle, useRef, useState, type Ref } from 'react';
import { StyleSheet } from 'react-native';
import MapView, { Marker, type EdgePadding, type Region } from 'react-native-maps';

import { DevelopmentLocationMarker } from '@/components/map/development-location-marker';
import { NetworkStationMarkers } from '@/components/map/network-station-markers';
import { RouteLines } from '@/components/map/route-lines';
import { StationMarkers } from '@/components/map/station-markers';
import { PARIS_COORDINATE } from '@/features/home-map/model/location';
import { routeBounds, type LineView } from '@/lib/metro-network';

const INITIAL_REGION: Region = {
  ...PARIS_COORDINATE,
  latitudeDelta: 0.13,
  longitudeDelta: 0.29,
};
/**
 * Stations mount below the show level and unmount above the hide one. The gap
 * keeps a pinch held right at the boundary from thrashing ~300 marker views.
 * Mount state, not marker opacity, because animated marker props silently
 * no-op under Fabric — react-native-maps only applies them on a React commit.
 */
const STATION_SHOW_DELTA = 0.1;
const STATION_HIDE_DELTA = 0.12;

export type MetroMapHandle = {
  /**
   * Frames a line's full extent. The caller decides *when*; this only knows how.
   * It takes the route rather than the `LineView` because framing needs the
   * track and nothing else — passing the whole view would invite handing it one
   * line's stations with another line's geometry.
   */
  fitToRoute: (route: NetworkRoute, options?: { animated?: boolean }) => void;
  focusCoordinate: (coordinate: Coordinate, options?: { animated?: boolean }) => void;
};

type MetroMapProps = {
  /** The whole network, drawn muted underneath. */
  lines: NetworkRoute[];
  /** Every station, dotted over the network while no line is in focus. */
  stations: NetworkStation[];
  /** The line in focus, with its stations. Absent until the network has loaded. */
  line: LineView | undefined;
  /** Room the caller's overlay needs around a fitted line. */
  edgePadding: EdgePadding;
  focusedStation?: { coordinate: Coordinate; name: string };
  /** Development fallback shown because the native user-location dot is unavailable there. */
  developmentLocation?: Coordinate;
  /** Fires once the native map can accept a camera command. */
  onReady?: () => void;
  showsUserLocation?: boolean;
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
export function MetroMap({
  lines,
  stations,
  line,
  edgePadding,
  focusedStation,
  developmentLocation,
  onReady,
  ref,
  showsUserLocation = false,
}: MetroMapProps) {
  const mapRef = useRef<MapView>(null);
  const [stationsVisible, setStationsVisible] = useState(false);

  useImperativeHandle(
    ref,
    () => ({
      fitToRoute(route, { animated = true } = {}) {
        const bounds = routeBounds(route);
        if (bounds.length === 0) return;
        mapRef.current?.fitToCoordinates(bounds, { animated, edgePadding });
      },
      focusCoordinate(coordinate, { animated = true } = {}) {
        const latitudeDelta = 0.0025;
        const longitudeDelta = 0.004;
        mapRef.current?.fitToCoordinates(
          [
            {
              latitude: coordinate.latitude - latitudeDelta,
              longitude: coordinate.longitude - longitudeDelta,
            },
            {
              latitude: coordinate.latitude + latitudeDelta,
              longitude: coordinate.longitude + longitudeDelta,
            },
          ],
          { animated, edgePadding }
        );
      },
    }),
    [edgePadding]
  );

  return (
    <MapView
      ref={mapRef}
      style={styles.map}
      initialRegion={INITIAL_REGION}
      mapType="mutedStandard"
      loadingEnabled
      loadingBackgroundColor="#F5F4EF"
      loadingIndicatorColor="#1D1D1F"
      pitchEnabled={false}
      rotateEnabled={false}
      showsBuildings={false}
      showsCompass={false}
      showsIndoors={false}
      showsPointsOfInterests={false}
      showsUserLocation={showsUserLocation}
      showsTraffic={false}
      onMapReady={onReady}
      onRegionChange={(region) => {
        const visible = stationZoomVisibility(region.longitudeDelta);
        if (visible !== undefined) setStationsVisible(visible);
      }}
    >
      <RouteLines routes={lines} selectedRoute={line?.route} />
      {!stationsVisible ? null : line ? (
        <StationMarkers line={line} />
      ) : (
        <NetworkStationMarkers routes={lines} stations={stations} />
      )}
      {focusedStation ? (
        <Marker
          coordinate={focusedStation.coordinate}
          pinColor="#2F6B5B"
          title={focusedStation.name}
          tracksViewChanges={false}
        />
      ) : null}
      {developmentLocation ? <DevelopmentLocationMarker coordinate={developmentLocation} /> : null}
    </MapView>
  );
}

/** true past the show level, false past the hide one, undefined in between. */
function stationZoomVisibility(longitudeDelta: number) {
  if (longitudeDelta < STATION_SHOW_DELTA) return true;
  if (longitudeDelta > STATION_HIDE_DELTA) return false;
  return undefined;
}

const styles = StyleSheet.create({
  map: { flex: 1 },
});

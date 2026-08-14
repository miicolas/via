import type { Coordinate, Journey, NetworkRoute, NetworkStation, RouteBadge } from '@via/contract';
import { useImperativeHandle, useMemo, useRef, useState, type Ref } from 'react';
import { StyleSheet, useWindowDimensions } from 'react-native';
import MapView, { type EdgePadding, type Region } from 'react-native-maps';
import { useReducedMotion, useSharedValue } from 'react-native-reanimated';

import { DevelopmentLocationMarker } from '@/components/map/development-location-marker';
import { JourneyRouteLayer } from '@/components/map/journey-route-layer';
import { RouteLines } from '@/components/map/route-lines';
import { StationMarkersLayer } from '@/components/map/station-markers-layer';
import { PARIS_COORDINATE } from '@/features/map/model/location';
import { routeBounds, type LineView } from '@/lib/metro-network';
import { journeySectionCoordinates } from '@/lib/journey-map-geometry';
import { stationsInViewport } from '@/lib/stations-in-viewport';
import {
  alignLineWithRouteLayout,
  positionTransitRoutes,
  prepareTransitRouteLayout,
} from '@/lib/transit-map-layout';
import { stationFocusRegion } from '@/lib/station-focus-region';

const INITIAL_REGION: Region = {
  ...PARIS_COORDINATE,
  latitudeDelta: 0.13,
  longitudeDelta: 0.29,
};
/**
 * Station opacity follows the fractional zoom between the show and hide levels.
 * Native marker views mount as the fade begins and only unmount once zooming ends,
 * avoiding both a late pop and mount thrashing around the boundary.
 * Around Paris, stations appear inside roughly a 300 m radius and disappear
 * beyond roughly 440 m from the map centre,
 * so stations remain a neighbourhood-scale detail instead of covering the city.
 * The marker layer keeps native snapshots updating until this fade settles.
 */
const STATION_SHOW_DELTA = 0.008;
const STATION_HIDE_DELTA = 0.012;
const STATION_FOCUS_ANIMATION_DURATION_MS = 1_000;

type StationMarkersState = {
  mounted: boolean;
  tracking: boolean;
};

export type MetroMapHandle = {
  /**
   * Frames a line's full extent. The caller decides *when*; this only knows how.
   * It takes the route rather than the `LineView` because framing needs the
   * track and nothing else — passing the whole view would invite handing it one
   * line's stations with another line's geometry.
   */
  fitToRoute: (route: NetworkRoute, options?: { animated?: boolean }) => void;
  focusCoordinate: (coordinate: Coordinate, options?: { animated?: boolean }) => void;
  fitToJourney: (journey: Journey, options?: { animated?: boolean }) => void;
};

type MetroMapProps = {
  /** The whole network, drawn muted underneath. */
  lines: NetworkRoute[];
  /** Every loaded station, dotted over the network while no line is in focus. */
  stations: NetworkStation[];
  /** Badges for every route `stations` can reference — rail lines and viewport-loaded bus lines. */
  stationRoutes: RouteBadge[];
  /** The line in focus, with its stations. Absent until the network has loaded. */
  line: LineView | undefined;
  /** Room the caller's overlay needs around a fitted line. */
  edgePadding: EdgePadding;
  /** Development fallback shown because the native user-location dot is unavailable there. */
  developmentLocation?: Coordinate;
  /** Fires once the native map can accept a camera command. */
  onReady?: () => void;
  /** Fires when a station marker is selected. */
  onSelectStation: (stationId: string, coordinate: Coordinate) => void;
  /** Fires when the camera moves from a user gesture, not a programmatic command. */
  onUserMove?: () => void;
  /**
   * Fires with every camera region, during and after movement. The tile loader
   * behind it debounces and decides whether the zoom warrants fetching, so the
   * map only has to report what is on screen.
   */
  onViewportChange?: (region: Region) => void;
  showsUserLocation?: boolean;
  /** The selected journey route, drawn above the muted transit network. */
  journey?: Journey;
  /** Height of the map viewport, used to center a station in the unobscured area. */
  viewportHeight: number;
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
  stationRoutes,
  line,
  edgePadding,
  developmentLocation,
  onReady,
  onSelectStation,
  onUserMove,
  onViewportChange,
  journey,
  ref,
  showsUserLocation = false,
  viewportHeight,
}: MetroMapProps) {
  const mapRef = useRef<MapView>(null);
  const { width: viewportWidth } = useWindowDimensions();
  const reduceMotion = useReducedMotion();
  const stationOpacity = useSharedValue(0);
  const reducedMotionVisibility = useRef(false);
  const lastStationOpacity = useRef(0);
  // Apple Maps does not provide details.isGesture, so track camera commands issued here.
  const programmaticCameraMove = useRef(false);
  const [stationMarkersState, setStationMarkersState] = useState<StationMarkersState>({
    mounted: false,
    tracking: false,
  });
  const [layoutRegion, setLayoutRegion] = useState(INITIAL_REGION);
  const routeLayout = useMemo(() => prepareTransitRouteLayout(lines), [lines]);
  const positionedLines = useMemo(
    () =>
      positionTransitRoutes(routeLayout, {
        height: viewportHeight,
        latitudeDelta: layoutRegion.latitudeDelta,
        longitudeDelta: layoutRegion.longitudeDelta,
        width: viewportWidth,
      }),
    [
      layoutRegion.latitudeDelta,
      layoutRegion.longitudeDelta,
      routeLayout,
      viewportHeight,
      viewportWidth,
    ]
  );
  const positionedLine = useMemo(
    () => alignLineWithRouteLayout(line, positionedLines),
    [line, positionedLines]
  );
  const viewportStations = useMemo(
    () => stationsInViewport(stations, layoutRegion),
    [layoutRegion, stations]
  );
  const updateStationOpacity = (longitudeDelta: number, movementComplete = false) => {
    const nextOpacity = reduceMotion
      ? reducedMotionStationOpacity(longitudeDelta, reducedMotionVisibility)
      : stationZoomOpacity(longitudeDelta);
    const opacityChanged = nextOpacity !== lastStationOpacity.current;

    if (opacityChanged) {
      lastStationOpacity.current = nextOpacity;
      stationOpacity.value = nextOpacity;
    }

    if (!opacityChanged && !movementComplete) return;

    setStationMarkersState((current) => {
      const next = {
        mounted: movementComplete ? nextOpacity > 0 : current.mounted || nextOpacity > 0,
        tracking: movementComplete ? false : current.tracking || opacityChanged,
      };
      return next.mounted === current.mounted && next.tracking === current.tracking
        ? current
        : next;
    });
  };

  useImperativeHandle(
    ref,
    () => ({
      fitToRoute(route, { animated = true } = {}) {
        const bounds = routeBounds(route);
        if (bounds.length === 0) return;
        const nativeMap = mapRef.current;
        if (!nativeMap) return;
        programmaticCameraMove.current = true;
        nativeMap.fitToCoordinates(bounds, { animated, edgePadding });
      },
      focusCoordinate(coordinate, { animated = true } = {}) {
        const region = stationFocusRegion(coordinate, edgePadding, viewportHeight);
        const nativeMap = mapRef.current;
        if (!nativeMap) return;
        programmaticCameraMove.current = true;
        nativeMap.animateToRegion(region, animated ? STATION_FOCUS_ANIMATION_DURATION_MS : 0);
      },
      fitToJourney(selectedJourney, { animated = true } = {}) {
        const coordinates = selectedJourney.sections.flatMap(journeySectionCoordinates);
        if (coordinates.length < 2) return;
        const nativeMap = mapRef.current;
        if (!nativeMap) return;
        programmaticCameraMove.current = true;
        nativeMap.fitToCoordinates(coordinates, { animated, edgePadding });
      },
    }),
    [edgePadding, viewportHeight]
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
      onRegionChange={(region, details) => {
        updateStationOpacity(region.longitudeDelta);
        onViewportChange?.(region);
        if (programmaticCameraMove.current || details?.isGesture === false) return;
        onUserMove?.();
      }}
      onRegionChangeComplete={(region) => {
        setLayoutRegion((current) =>
          sameMapViewport(current, region) ? current : region
        );
        updateStationOpacity(region.longitudeDelta, true);
        onViewportChange?.(region);
        programmaticCameraMove.current = false;
      }}
    >
      <RouteLines muted={Boolean(journey)} routes={positionedLines} selectedRoute={positionedLine?.route} />
      <JourneyRouteLayer journey={journey} />
      <StationMarkersLayer
        line={positionedLine}
        routes={stationRoutes}
        stations={viewportStations}
        opacity={stationOpacity}
        tracksViewChanges={stationMarkersState.tracking}
        visible={stationMarkersState.mounted}
        onSelectStation={onSelectStation}
      />
      {developmentLocation ? <DevelopmentLocationMarker coordinate={developmentLocation} /> : null}
    </MapView>
  );
}

function stationZoomOpacity(longitudeDelta: number) {
  const fadeProgress =
    (STATION_HIDE_DELTA - longitudeDelta) /
    (STATION_HIDE_DELTA - STATION_SHOW_DELTA);
  return Math.min(1, Math.max(0, fadeProgress));
}

function reducedMotionStationOpacity(
  longitudeDelta: number,
  visibility: { current: boolean }
) {
  if (longitudeDelta < STATION_SHOW_DELTA) visibility.current = true;
  if (longitudeDelta > STATION_HIDE_DELTA) visibility.current = false;
  return visibility.current ? 1 : 0;
}

function sameMapViewport(first: Region, second: Region) {
  const latitudeTolerance = Math.max(first.latitudeDelta * 0.02, 1e-6);
  const longitudeTolerance = Math.max(first.longitudeDelta * 0.02, 1e-6);
  return (
    Math.abs(first.latitude - second.latitude) < latitudeTolerance &&
    Math.abs(first.longitude - second.longitude) < longitudeTolerance &&
    Math.abs(first.latitudeDelta - second.latitudeDelta) < 1e-8 &&
    Math.abs(first.longitudeDelta - second.longitudeDelta) < 1e-8
  );
}

const styles = StyleSheet.create({
  map: { flex: 1 },
});

import { afterAll, beforeAll, beforeEach, describe, expect, mock, test } from 'bun:test';

type ElementNode = {
  type: unknown;
  props: Record<string, unknown> & { children?: unknown };
};

let stationMarkersState = { mounted: false, tracking: false };
let layoutRegion = {
  latitude: 48.86,
  longitude: 2.35,
  latitudeDelta: 0.13,
  longitudeDelta: 0.29,
};
let overviewDetentIndex = 0;
let safeAreaTop = 0;
const pendingRefValues: unknown[] = [];
const focusCoordinate = mock(() => undefined);
const selectResult = mock(() => undefined);
const selectStation = mock(() => undefined);
const setOverviewDetentIndex = mock(() => undefined);

const jsx = (type: unknown, props: Record<string, unknown>): ElementNode => ({ type, props });

beforeAll(() => {
  mock.module('react', () => ({
    useCallback: (callback: unknown) => callback,
    useEffect: () => undefined,
    useImperativeHandle: (
      ref: { current: unknown } | undefined,
      createHandle: () => unknown
    ) => {
      if (ref) ref.current = createHandle();
    },
    useMemo: (createValue: () => unknown) => createValue(),
    useRef: (current: unknown) => ({
      current: current === null && pendingRefValues.length > 0 ? pendingRefValues.shift() : current,
    }),
    useState: (initial: unknown) => {
      if (
        typeof initial === 'object' &&
        initial !== null &&
        'latitudeDelta' in initial
      ) {
        return [
          layoutRegion,
          (next: typeof layoutRegion | ((current: typeof layoutRegion) => typeof layoutRegion)) => {
            layoutRegion = typeof next === 'function' ? next(layoutRegion) : next;
          },
        ];
      }

      if (
        typeof initial === 'object' &&
        initial !== null &&
        'mounted' in initial &&
        'tracking' in initial
      ) {
        return [
          stationMarkersState,
          (
            next:
              | typeof stationMarkersState
              | ((current: typeof stationMarkersState) => typeof stationMarkersState)
          ) => {
            stationMarkersState =
              typeof next === 'function' ? next(stationMarkersState) : next;
          },
        ];
      }

      return [
        false,
        (next: boolean | ((current: boolean) => boolean)) => {
          void next;
        },
      ];
    },
  }));
  mock.module('react/jsx-dev-runtime', () => ({ Fragment: 'Fragment', jsxDEV: jsx }));
  mock.module('react/jsx-runtime', () => ({ Fragment: 'Fragment', jsx, jsxs: jsx }));
  mock.module('react-native', () => ({
    StyleSheet: { create: (styles: Record<string, unknown>) => styles },
    Text: 'Text',
    useWindowDimensions: () => ({ height: 1_000, width: 400 }),
    View: 'View',
  }));
  mock.module('react-native-maps', () => ({ default: 'MapView', Marker: 'Marker' }));
  mock.module('react-native-reanimated', () => ({
    default: { ScrollView: 'AnimatedScrollView', View: 'AnimatedView' },
    Extrapolation: { CLAMP: 'clamp' },
    interpolate: () => 1,
    useAnimatedScrollHandler: (handlers: { onScroll: unknown }) => handlers.onScroll,
    useAnimatedStyle: () => ({ opacity: 1 }),
    useReducedMotion: () => false,
    useSharedValue: (value: number) => ({ value }),
  }));
  mock.module('@/components/map/development-location-marker', () => ({
    DevelopmentLocationMarker: 'DevelopmentLocationMarker',
  }));
  mock.module('@/components/map/map-status', () => ({ MapStatus: 'MapStatus' }));
  mock.module('@/components/map/network-station-markers', () => ({
    NetworkStationMarkers: 'NetworkStationMarkers',
  }));
  mock.module('@/components/map/route-lines', () => ({ RouteLines: 'RouteLines' }));
  mock.module('@/components/map/station-dot', () => ({ StationDot: 'StationDot' }));
  mock.module('@/components/map/station-markers-layer', () => ({
    StationMarkersLayer: 'StationMarkersLayer',
  }));
  mock.module('@/components/map/station-markers', () => ({
    StationMarkers: 'StationMarkers',
  }));
  mock.module('@/features/home-map/model/location', () => ({
    PARIS_COORDINATE: { latitude: 48.86, longitude: 2.35 },
  }));
  mock.module('@/features/home-map/components/recenter-button', () => ({
    HomeRecenterButton: 'HomeRecenterButton',
  }));
  mock.module('@/features/home-map/components/overview-sheet', () => ({
    HomeOverviewSheet: 'HomeOverviewSheet',
  }));
  mock.module('@/features/home-map/components/tab-behind-sheet', () => ({
    TabBehindSheet: 'TabBehindSheet',
  }));
  mock.module('@/features/home-map/hooks/use-map', () => ({
    useHomeMap: () => ({
      activeStation: undefined,
      networkState: { status: 'ready', lines: [], stations: [] },
      overviewDetentIndex,
      refreshLocation: async () => undefined,
      retryNetwork: () => undefined,
      selectResult,
      selectStation,
      setOverviewDetentIndex,
      userLocation: { status: 'loading' },
    }),
  }));
  mock.module('@/lib/metro-network', () => ({ routeBounds: () => [] }));
  mock.module('react-native-safe-area-context', () => ({
    useSafeAreaInsets: () => ({ top: safeAreaTop, right: 0, bottom: 0, left: 0 }),
  }));
});

afterAll(() => mock.restore());
beforeEach(() => {
  stationMarkersState = { mounted: false, tracking: false };
});

describe('MetroMap station visibility', () => {
  test('keeps the station layer mounted so it can fade between zoom levels', async () => {
    const { MetroMap } = await import('@/components/map/metro-map');
    const props = {
      edgePadding: { top: 0, right: 0, bottom: 0, left: 0 },
      line: undefined,
      lines: [],
      markerSnapshotVersion: 0,
      onSelectStation: () => undefined,
      stations: [],
      viewportHeight: 1_000,
    };

    let tree = MetroMap(props) as unknown as ElementNode;
    const onRegionChangeComplete = tree.props.onRegionChangeComplete as (
      region: typeof layoutRegion
    ) => void;

    onRegionChangeComplete({ ...layoutRegion, latitudeDelta: 0.007, longitudeDelta: 0.007 });
    tree = MetroMap(props) as unknown as ElementNode;

    expect(stationLayer(tree.props.children)?.props.visible).toBe(true);

    onRegionChangeComplete({ ...layoutRegion, latitudeDelta: 0.013, longitudeDelta: 0.013 });
    tree = MetroMap(props) as unknown as ElementNode;

    expect(stationLayer(tree.props.children)?.props.visible).toBe(false);
  });

  test('fades station icons while zooming out before the gesture completes', async () => {
    const { MetroMap } = await import('@/components/map/metro-map');
    const props = {
      edgePadding: { top: 0, right: 0, bottom: 0, left: 0 },
      line: undefined,
      lines: [],
      markerSnapshotVersion: 0,
      onSelectStation: () => undefined,
      stations: [],
      viewportHeight: 1_000,
    };

    const tree = MetroMap(props) as unknown as ElementNode;
    const onRegionChange = tree.props.onRegionChange as (region: typeof layoutRegion) => void;
    const layer = stationLayer(tree.props.children);
    const opacity = layer?.props.opacity as { value: number };

    onRegionChange({ ...layoutRegion, latitudeDelta: 0.01, longitudeDelta: 0.01 });

    expect(opacity.value).toBeGreaterThan(0);
    expect(opacity.value).toBeLessThan(1);
  });

  test('shows stations after a programmatic camera movement completes', async () => {
    const { MetroMap } = await import('@/components/map/metro-map');
    const props = {
      edgePadding: { top: 0, right: 0, bottom: 0, left: 0 },
      line: undefined,
      lines: [],
      markerSnapshotVersion: 0,
      onSelectStation: () => undefined,
      stations: [],
      viewportHeight: 1_000,
    };
    let tree = MetroMap(props) as unknown as ElementNode;
    const onRegionChangeComplete = tree.props.onRegionChangeComplete as (
      region: typeof layoutRegion
    ) => void;

    onRegionChangeComplete({ ...layoutRegion, latitudeDelta: 0.006, longitudeDelta: 0.006 });
    tree = MetroMap(props) as unknown as ElementNode;

    expect(stationLayer(tree.props.children)?.props.visible).toBe(true);
  });
});

test('pressing a station marker selects its station and coordinate', async () => {
  const { StationMarker } = await import('@/components/map/station-marker');
  const coordinate = { latitude: 48.853, longitude: 2.333 };
  const onSelectStation = mock(() => undefined);

  const tree = StationMarker({
    colors: ['#FFCD00'],
    coordinate,
    lineCount: 1,
    modes: ['metro'],
    name: 'Saint-Germain-des-Prés',
    opacity: { value: 1 } as never,
    onSelectStation,
    stationId: 'saint-germain-des-pres',
    tracksViewChanges: false,
  }) as unknown as ElementNode;

  expect(tree.props.accessibilityRole).toBe('button');
  (tree.props.onPress as () => void)();

  expect(onSelectStation).toHaveBeenCalledWith('saint-germain-des-pres', coordinate);
});

test('selecting a map station focuses it inside the resident overview sheet', async () => {
  focusCoordinate.mockClear();
  selectStation.mockClear();

  const { MetroMapScreen } = await import('@/components/map/metro-map-screen');
  const coordinate = { latitude: 48.853, longitude: 2.333 };
  pendingRefValues.push({ focusCoordinate });
  const tree = MetroMapScreen() as unknown as ElementNode;
  const map = elementWithProp(tree.props.children, 'onSelectStation');

  expect(map).toBeDefined();
  const onSelectStation = map?.props.onSelectStation as (
    stationId: string,
    selectedCoordinate: typeof coordinate
  ) => void;
  onSelectStation('saint-germain-des-pres', coordinate);

  expect(focusCoordinate).toHaveBeenCalledWith(coordinate, { animated: true });
  expect(selectStation).toHaveBeenCalledWith('saint-germain-des-pres');
});

test('the overview sheet content lives inside the persistent tab-behind sheet', async () => {
  const { MetroMapScreen } = await import('@/components/map/metro-map-screen');
  const tree = MetroMapScreen() as unknown as ElementNode;
  const sheet = elementWithProp(tree.props.children, 'detentFractions');
  const overview = childElements(sheet?.props.children).find(
    (child) => child.type === 'HomeOverviewSheet'
  );

  expect(overview).toBeDefined();
  expect(sheet?.props.onDetentChange).toBe(setOverviewDetentIndex);
});

test('the station focus padding follows all persistent sheet detents', async () => {
  const { MetroMapScreen } = await import('@/components/map/metro-map-screen');

  safeAreaTop = 60;
  overviewDetentIndex = 0;
  const collapsedTree = MetroMapScreen() as unknown as ElementNode;
  const collapsedMap = elementWithProp(collapsedTree.props.children, 'onSelectStation');

  overviewDetentIndex = 1;
  const openTree = MetroMapScreen() as unknown as ElementNode;
  const openMap = elementWithProp(openTree.props.children, 'onSelectStation');

  overviewDetentIndex = 2;
  const expandedTree = MetroMapScreen() as unknown as ElementNode;
  const expandedMap = elementWithProp(expandedTree.props.children, 'onSelectStation');

  const collapsedPadding = collapsedMap?.props.edgePadding as { bottom: number; top: number };
  const openPadding = openMap?.props.edgePadding as { bottom: number; top: number };
  const expandedPadding = expandedMap?.props.edgePadding as { bottom: number; top: number };

  expect(collapsedPadding).toMatchObject({ bottom: 132, top: 68 });
  expect(openPadding).toMatchObject({ bottom: 395, top: 68 });
  expect(expandedPadding).toMatchObject({ bottom: 846, top: 68 });
  safeAreaTop = 0;
});

test('focusCoordinate centers a marker in the unobscured map without hiding station markers', async () => {
  const { MetroMap } = await import('@/components/map/metro-map');
  const animateToRegion = mock(() => undefined);
  const fitToCoordinates = mock(() => undefined);
  const nativeMap = { animateToRegion, fitToCoordinates };
  const ref = { current: null };
  const coordinate = { latitude: 48.853, longitude: 2.333 };
  const edgePadding = { top: 100, right: 24, bottom: 700, left: 24 };

  pendingRefValues.push(nativeMap);
  MetroMap({
    edgePadding,
    line: undefined,
    lines: [],
    markerSnapshotVersion: 0,
    onSelectStation: () => undefined,
    ref,
    stations: [],
    viewportHeight: 1_000,
  } as never);

  (ref.current as unknown as {
    focusCoordinate: (selected: typeof coordinate, options: { animated: boolean }) => void;
  }).focusCoordinate(coordinate, { animated: false });

  expect(animateToRegion).toHaveBeenCalledTimes(1);
  const [region] = animateToRegion.mock.calls[0] as unknown as [{
    latitude: number;
    latitudeDelta: number;
    longitude: number;
    longitudeDelta: number;
  }];
  const stationY =
    500 - ((coordinate.latitude - region.latitude) / region.latitudeDelta) * 1_000;

  expect(region.longitudeDelta).toBeLessThan(0.008);
  expect(stationY).toBeCloseTo(200, 0);
});

const childElements = (children: unknown) =>
  [children].flat(Number.POSITIVE_INFINITY).filter(
    (child): child is ElementNode =>
      typeof child === 'object' && child !== null && 'props' in child
  );

const stationLayer = (children: unknown) =>
  childElements(children).find((child) => child.type === 'StationMarkersLayer');

const elementWithProp = (children: unknown, prop: string) =>
  childElements(children).find((child) => prop in child.props);

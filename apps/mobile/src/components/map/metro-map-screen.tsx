import type { Coordinate } from '@via/contract';
import { type Href, usePathname, useRouter } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { MapStatus } from '@/components/map/map-status';
import { MetroMap, type MetroMapHandle } from '@/components/map/metro-map';
import { HomeRecenterButton } from '@/features/home-map/components/recenter-button';
import { useHomeMap } from '@/features/home-map/hooks/use-map';
import { mapOverviewSheetDetent } from '@/features/home-map/model/overview-sheet';

const MAP_OVERVIEW_HREF = '/map/overview' as Href;
const CLOSED_MAP_OVERLAY_HEIGHT = 112;
const OPEN_MAP_TOP_GAP = 8;

export function MetroMapScreen() {
  const pathname = usePathname();
  const router = useRouter();
  const mapRef = useRef<MetroMapHandle>(null);
  const lastFocusedStationKey = useRef<string | undefined>(undefined);
  const [mapReady, setMapReady] = useState(false);
  const [centeredOnUser, setCenteredOnUser] = useState(false);
  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const {
    activeStation,
    networkState,
    overviewDetentIndex,
    refreshLocation,
    retryNetwork,
    selectStation,
    userLocation,
  } = useHomeMap();
  const overviewVisible = pathname === '/map/overview';
  const overviewDetent = mapOverviewSheetDetent(overviewDetentIndex);

  useEffect(() => {
    if (!mapReady || !activeStation) return;

    const focusKey = `${activeStation.station.id}:${overviewVisible ? `sheet:${overviewDetentIndex}` : 'map'}`;
    if (lastFocusedStationKey.current === focusKey) return;

    lastFocusedStationKey.current = focusKey;
    mapRef.current?.focusCoordinate(activeStation.coordinate, { animated: true });
    setCenteredOnUser(false);
  }, [activeStation, mapReady, overviewDetentIndex, overviewVisible]);

  const selectMapStation = useCallback(
    (stationId: string, coordinate: Coordinate) => {
      // Focus from the tap itself, including when the already-active station is tapped again.
      lastFocusedStationKey.current = `${stationId}:${overviewVisible ? 'sheet' : 'map'}`;
      mapRef.current?.focusCoordinate(coordinate, { animated: true });
      setCenteredOnUser(false);
      selectStation(stationId);
      // Navigate reuses an already-present overview instead of stacking a second sheet.
      router.navigate(MAP_OVERVIEW_HREF);
    },
    [overviewVisible, router, selectStation]
  );

  const recenter = () => {
    if (userLocation.status === 'ready') {
      mapRef.current?.focusCoordinate(userLocation.coordinate, { animated: true });
      setCenteredOnUser(true);
      return;
    }
    void refreshLocation();
  };

  const developmentLocation =
    userLocation.status === 'ready' && userLocation.source === 'development-default'
      ? userLocation.coordinate
      : undefined;

  return (
    <View style={styles.container}>
      <MetroMap
        ref={mapRef}
        edgePadding={{
          top: insets.top + (overviewVisible ? OPEN_MAP_TOP_GAP : 72),
          right: 24,
          bottom: overviewVisible
            ? Math.round((height - insets.top) * overviewDetent)
            : insets.bottom + CLOSED_MAP_OVERLAY_HEIGHT,
          left: 24,
        }}
        developmentLocation={developmentLocation}
        line={undefined}
        lines={networkState.status === 'ready' ? networkState.lines : []}
        markerSnapshotVersion={overviewVisible ? overviewDetentIndex + 1 : 0}
        stations={networkState.status === 'ready' ? networkState.stations : []}
        onReady={() => setMapReady(true)}
        onSelectStation={selectMapStation}
        onUserMove={() => setCenteredOnUser(false)}
        showsUserLocation={
          userLocation.status === 'ready' && userLocation.source === 'device'
        }
        viewportHeight={height}
      />

      {centeredOnUser ? null : (
        <View style={[styles.mapControls, { top: insets.top + 16 }]}>
          <HomeRecenterButton
            isLoading={userLocation.status === 'loading'}
            onPress={recenter}
          />
        </View>
      )}
      {networkState.status !== 'ready' ? (
        <MapStatus onRetry={retryNetwork} state={networkState} />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  mapControls: {
    position: 'absolute',
    right: 16,
    alignItems: 'flex-end',
  },
});

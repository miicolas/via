import { useEffect, useRef, useState } from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { MapStatus } from '@/components/map/map-status';
import { MetroMap, type MetroMapHandle } from '@/components/map/metro-map';
import { HomeRecenterButton } from '@/features/home-map/recenter-button';
import { useHomeMap } from '@/features/home-map/use-map';

export function MetroMapScreen() {
  const mapRef = useRef<MetroMapHandle>(null);
  const lastFocusedStationId = useRef<string | undefined>(undefined);
  const [mapReady, setMapReady] = useState(false);
  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const {
    activeStation,
    networkState,
    refreshLocation,
    retryNetwork,
    userLocation,
  } = useHomeMap();

  useEffect(() => {
    if (
      !mapReady ||
      !activeStation ||
      lastFocusedStationId.current === activeStation.station.id
    ) {
      return;
    }
    lastFocusedStationId.current = activeStation.station.id;
    mapRef.current?.focusCoordinate(activeStation.coordinate, { animated: true });
  }, [activeStation, mapReady]);

  const recenter = () => {
    if (userLocation.status === 'ready') {
      mapRef.current?.focusCoordinate(userLocation.coordinate, { animated: true });
      return;
    }
    void refreshLocation();
  };

  return (
    <View style={styles.container}>
      <MetroMap
        ref={mapRef}
        edgePadding={{
          top: insets.top + 72,
          right: 24,
          bottom: Math.round(height * 0.47),
          left: 24,
        }}
        focusedStation={
          activeStation
            ? { coordinate: activeStation.coordinate, name: activeStation.station.name }
            : undefined
        }
        line={undefined}
        lines={networkState.status === 'ready' ? networkState.lines : []}
        onReady={() => setMapReady(true)}
        showsUserLocation={userLocation.status === 'ready'}
      />

      <View style={[styles.mapControls, { top: insets.top + 16 }]}>
        <HomeRecenterButton
          isLoading={userLocation.status === 'loading'}
          onPress={recenter}
        />
      </View>
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

import type { Coordinate } from '@via/contract';
import { useCallback, useEffect, useRef, useState } from 'react';
import { StyleSheet, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { MapStatus } from '@/components/map/map-status';
import { MetroMap, type MetroMapHandle } from '@/components/map/metro-map';
import { OverviewSheet } from '@/features/map/components/overview-sheet';
import { RecenterButton } from '@/features/map/components/recenter-button';
import { TabBehindSheet } from '@/features/map/components/tab-behind-sheet';
import { useMap } from '@/features/map/hooks/use-map';
import {
  MAP_JOURNEY_SHEET_DETENTS,
  MAP_OVERVIEW_SHEET_DETENTS,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
  mapOverviewSheetDetent,
} from '@/features/map/model/overview-sheet';
import { stationFocusKey } from '@/features/map/model/station-focus-key';

const OPEN_MAP_TOP_GAP = 8;

export function MetroMapScreen() {
  const mapRef = useRef<MetroMapHandle>(null);
  const lastFocusedStationKey = useRef<string | undefined>(undefined);
  const lastFocusedJourneyKey = useRef<string | undefined>(undefined);
  const [mapReady, setMapReady] = useState(false);
  const [centeredOnUser, setCenteredOnUser] = useState(false);
  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const {
    activeStation,
    flow,
    networkState,
    overviewDetentIndex,
    refreshLocation,
    retryNetwork,
    selectStation,
    selectedJourney,
    setOverviewDetentIndex,
    userLocation,
  } = useMap();
  const journeySheetActive =
    flow.screen === 'planning' || flow.screen === 'results' || flow.screen === 'detail';
  const sheetDetents = journeySheetActive
    ? MAP_JOURNEY_SHEET_DETENTS
    : MAP_OVERVIEW_SHEET_DETENTS;
  const overviewDetent = journeySheetActive
    ? (sheetDetents[overviewDetentIndex] ?? sheetDetents[MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX])
    : mapOverviewSheetDetent(overviewDetentIndex);

  useEffect(() => {
    if (!mapReady || !activeStation || journeySheetActive) return;

    const focusKey = stationFocusKey(activeStation.station.id, overviewDetentIndex);
    if (lastFocusedStationKey.current === focusKey) return;

    lastFocusedStationKey.current = focusKey;
    mapRef.current?.focusCoordinate(activeStation.coordinate, { animated: true });
    setCenteredOnUser(false);
  }, [activeStation, journeySheetActive, mapReady, overviewDetentIndex]);

  useEffect(() => {
    if (!mapReady || flow.screen !== 'detail' || !selectedJourney) return;
    const focusKey = `${selectedJourney.id}:${overviewDetentIndex}`;
    if (lastFocusedJourneyKey.current === focusKey) return;
    lastFocusedJourneyKey.current = focusKey;
    mapRef.current?.fitToJourney(selectedJourney, { animated: true });
    setCenteredOnUser(false);
  }, [flow.screen, mapReady, overviewDetentIndex, selectedJourney]);

  const selectMapStation = useCallback(
    (stationId: string, coordinate: Coordinate) => {
      // Focus from the tap itself, including when the already-active station is tapped again.
      // selectStation reveals the sheet at its initial detent, so seed the key it produces.
      lastFocusedStationKey.current = stationFocusKey(
        stationId,
        MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX
      );
      mapRef.current?.focusCoordinate(coordinate, { animated: true });
      setCenteredOnUser(false);
      selectStation(stationId);
    },
    [selectStation]
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
          top: insets.top + OPEN_MAP_TOP_GAP,
          right: 24,
          bottom: Math.round((height - insets.top) * overviewDetent),
          left: 24,
        }}
        developmentLocation={developmentLocation}
        line={undefined}
        lines={networkState.status === 'ready' ? networkState.lines : []}
        journey={flow.screen === 'detail' ? selectedJourney : undefined}
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
          <RecenterButton
            isLoading={userLocation.status === 'loading'}
            onPress={recenter}
          />
        </View>
      )}
      {networkState.status !== 'ready' ? (
        <MapStatus onRetry={retryNetwork} state={networkState} />
      ) : null}

      <TabBehindSheet
        detentFractions={sheetDetents}
        detentIndex={overviewDetentIndex}
        onDetentChange={setOverviewDetentIndex}
        topInset={insets.top}>
        <OverviewSheet />
      </TabBehindSheet>
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

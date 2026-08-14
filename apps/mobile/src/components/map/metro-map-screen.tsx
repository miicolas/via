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
import { isJourneyScreen } from '@/features/map/model/journey-screen';
import {
  MAP_JOURNEY_DETAIL_SHEET_INITIAL_DETENT_INDEX,
  MAP_JOURNEY_SHEET_DETENTS,
  MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_DETENTS,
  MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX,
  mapOverviewSheetDetent,
} from '@/features/map/model/overview-sheet';

const OPEN_MAP_TOP_GAP = 8;

export function MetroMapScreen() {
  const mapRef = useRef<MetroMapHandle>(null);
  const [mapReady, setMapReady] = useState(false);
  const [centeredOnUser, setCenteredOnUser] = useState(false);
  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const {
    changeOverviewDetent,
    focusIntent,
    mapStations,
    networkState,
    overviewDetentIndex,
    refreshLocation,
    reportViewport,
    retryNetwork,
    screen,
    selectStation,
    selectedJourney,
    stationRoutes,
    userLocation,
  } = useMap();
  const journeySheetActive = isJourneyScreen(screen);
  const sheetDetents = journeySheetActive
    ? MAP_JOURNEY_SHEET_DETENTS
    : MAP_OVERVIEW_SHEET_DETENTS;
  const overviewDetent = journeySheetActive
    ? (sheetDetents[overviewDetentIndex] ?? sheetDetents[MAP_OVERVIEW_SHEET_INITIAL_DETENT_INDEX])
    : mapOverviewSheetDetent(overviewDetentIndex);

  useEffect(() => {
    if (!mapReady || !focusIntent) return;
    if (focusIntent.kind === 'station') {
      mapRef.current?.focusCoordinate(focusIntent.coordinate, { animated: true });
    } else {
      mapRef.current?.fitToJourney(focusIntent.journey, { animated: true });
    }
    setCenteredOnUser(false);
  }, [focusIntent, mapReady]);

  const selectMapStation = useCallback(
    (stationId: string, coordinate: Coordinate) => {
      setCenteredOnUser(false);
      selectStation(stationId, coordinate);
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
        journey={screen === 'detail' ? selectedJourney : undefined}
        stations={networkState.status === 'ready' ? mapStations : []}
        stationRoutes={stationRoutes}
        onReady={() => setMapReady(true)}
        onSelectStation={selectMapStation}
        onUserMove={() => setCenteredOnUser(false)}
        onViewportChange={reportViewport}
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
      {/* The overview sheet shows the same status itself; only float it over the map
          when the sheet is collapsed or replaced by the journey flow. */}
      {networkState.status !== 'ready' &&
      (overviewDetentIndex === MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX || journeySheetActive) ? (
        <View pointerEvents="box-none" style={[styles.mapStatus, { top: insets.top + 76 }]}>
          <MapStatus onRetry={retryNetwork} state={networkState} />
        </View>
      ) : null}

      <TabBehindSheet
        detentFractions={sheetDetents}
        detentIndex={overviewDetentIndex}
        minimumDetentIndex={
          screen === 'detail' ? MAP_JOURNEY_DETAIL_SHEET_INITIAL_DETENT_INDEX : undefined
        }
        onDetentChange={changeOverviewDetent}
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
  mapStatus: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
  },
});

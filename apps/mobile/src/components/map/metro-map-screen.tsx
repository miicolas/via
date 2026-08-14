import type { Coordinate } from "@via/contract";
import { useCallback, useEffect, useRef, useState } from "react";
import { StyleSheet, useWindowDimensions, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import { MapStatus } from "@/components/map/map-status";
import { MetroMap, type MetroMapHandle } from "@/components/map/metro-map";
import { OverviewSheet } from "@/features/map/components/overview-sheet";
import { TabBehindSheet } from "@/features/map/components/tab-behind-sheet";
import { useMap } from "@/features/map/hooks/use-map";
import { isJourneyScreen } from "@/features/map/model/journey-screen";
import {
  MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX,
  MAP_OVERVIEW_SHEET_DETENTS,
  mapOverviewSheetDetent,
} from "@/features/map/model/overview-sheet";

const OPEN_MAP_TOP_GAP = 8;

type MetroMapScreenProps = {
  onJourneyOpen?: () => void;
  onRecenterReady?: (recenter: () => void) => void;
};

export function MetroMapScreen({
  onJourneyOpen,
  onRecenterReady,
}: MetroMapScreenProps = {}) {
  const mapRef = useRef<MetroMapHandle>(null);
  const [mapReady, setMapReady] = useState(false);
  const insets = useSafeAreaInsets();
  const { height } = useWindowDimensions();
  const {
    chatOpen,
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
  const sheetActive = journeySheetActive || chatOpen;
  const overviewDetent = mapOverviewSheetDetent(overviewDetentIndex);

  useEffect(() => {
    if (!mapReady || !focusIntent) return;
    if (focusIntent.kind === "station") {
      mapRef.current?.focusCoordinate(focusIntent.coordinate, {
        animated: true,
      });
    } else {
      mapRef.current?.fitToJourney(focusIntent.journey, { animated: true });
    }
  }, [focusIntent, mapReady]);

  const selectMapStation = useCallback(
    (stationId: string, coordinate: Coordinate) => {
      if (selectStation(stationId, coordinate)) onJourneyOpen?.();
    },
    [onJourneyOpen, selectStation],
  );

  const recenter = useCallback(() => {
    if (userLocation.status === "ready") {
      mapRef.current?.focusCoordinate(userLocation.coordinate, {
        animated: true,
      });
      return;
    }
    void refreshLocation();
  }, [refreshLocation, userLocation]);

  useEffect(() => {
    onRecenterReady?.(recenter);
  }, [onRecenterReady, recenter]);

  const developmentLocation =
    userLocation.status === "ready" &&
    userLocation.source === "development-default"
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
        lines={networkState.status === "ready" ? networkState.lines : []}
        journey={journeySheetActive ? selectedJourney : undefined}
        stations={networkState.status === "ready" ? mapStations : []}
        stationRoutes={stationRoutes}
        onReady={() => setMapReady(true)}
        onSelectStation={selectMapStation}
        onViewportChange={reportViewport}
        showsUserLocation={
          userLocation.status === "ready" && userLocation.source === "device"
        }
        viewportHeight={height}
      />

      {/* The overview sheet shows the same status itself; only float it over the map
          when the sheet is collapsed or replaced by the journey flow. */}
      {networkState.status !== "ready" &&
      (overviewDetentIndex === MAP_OVERVIEW_SHEET_COLLAPSED_DETENT_INDEX ||
        sheetActive) ? (
        <View
          pointerEvents="box-none"
          style={[styles.mapStatus, { top: insets.top + 76 }]}
        >
          <MapStatus onRetry={retryNetwork} state={networkState} />
        </View>
      ) : null}

      {!sheetActive ? (
        <TabBehindSheet
          detentFractions={MAP_OVERVIEW_SHEET_DETENTS}
          detentIndex={overviewDetentIndex}
          onDetentChange={changeOverviewDetent}
          topInset={insets.top}
        >
          <OverviewSheet />
        </TabBehindSheet>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  mapStatus: {
    position: "absolute",
    left: 0,
    right: 0,
    alignItems: "center",
  },
});

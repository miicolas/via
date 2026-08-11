import { GlassView } from 'expo-glass-effect';
import { useMemo, useRef, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { MapStatus } from '@/components/map/map-status';
import { MetroMap, type MetroMapHandle } from '@/components/map/metro-map';
import { RouteSelector } from '@/components/map/route-selector';
import { RouteSummary } from '@/components/map/route-summary';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { BottomTabInset, Spacing } from '@/constants/theme';
import { useNetworkMap } from '@/hooks/use-network-map';
import { stationsOnRoute } from '@/lib/network-map';

/** Keeps a fitted line clear of the controls this screen floats over the map. */
const MAP_EDGE_PADDING = { top: 190, right: 24, bottom: 165, left: 24 };

export default function MapScreen() {
  const mapRef = useRef<MetroMapHandle>(null);
  const { status, routes, stations, error, reload } = useNetworkMap();
  const [pickedRouteId, setPickedRouteId] = useState<string>();

  const selectedRoute = routes.find((route) => route.id === pickedRouteId) ?? routes[0];
  // Kept stable so the memoised markers only rebuild when the line actually changes.
  const routeStations = useMemo(
    () => stationsOnRoute(stations, selectedRoute?.id),
    [stations, selectedRoute?.id]
  );

  if (process.env.EXPO_OS !== 'ios') {
    return (
      <ThemedView style={styles.unsupported}>
        <ThemedText type="subtitle">Carte disponible sur iPhone</ThemedText>
        <ThemedText themeColor="textSecondary" style={styles.centerText}>
          Cette première intégration est optimisée exclusivement pour iOS.
        </ThemedText>
      </ThemedView>
    );
  }

  return (
    <ThemedView style={styles.container}>
      <MetroMap
        ref={mapRef}
        routes={routes}
        selectedRoute={selectedRoute}
        stations={routeStations}
        edgePadding={MAP_EDGE_PADDING}
      />

      <SafeAreaView style={styles.overlay} pointerEvents="box-none">
        <View style={styles.topControls} pointerEvents="box-none">
          <RouteSummary route={selectedRoute} stations={routeStations} />
          {routes.length > 0 && (
            <RouteSelector
              routes={routes}
              selectedRouteId={selectedRoute?.id}
              onSelect={setPickedRouteId}
            />
          )}
        </View>

        <View style={styles.actions} pointerEvents="box-none">
          <GlassView glassEffectStyle="clear" isInteractive style={styles.actionGlass}>
            <Pressable
              accessibilityLabel={
                selectedRoute
                  ? `Recentrer sur toute la ligne ${selectedRoute.shortName}`
                  : 'Recentrer sur le métro'
              }
              accessibilityRole="button"
              hitSlop={8}
              onPress={() => mapRef.current?.fitSelectedRoute(true)}
              style={({ pressed }) => [styles.action, pressed && styles.pressed]}
            >
              <ThemedText type="smallBold">Recentrer</ThemedText>
            </Pressable>
          </GlassView>
        </View>
      </SafeAreaView>

      {status !== 'ready' && <MapStatus error={error} onRetry={reload} />}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  overlay: {
    position: 'absolute',
    inset: 0,
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.three,
    paddingTop: Spacing.three,
    paddingBottom: BottomTabInset + Spacing.three,
  },
  topControls: { gap: Spacing.two },
  actions: { alignSelf: 'flex-end' },
  actionGlass: {
    borderRadius: 22,
    borderCurve: 'continuous',
    overflow: 'hidden',
  },
  action: {
    minHeight: 44,
    justifyContent: 'center',
    paddingHorizontal: Spacing.three,
    borderRadius: 22,
  },
  pressed: { opacity: 0.6 },
  unsupported: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.two,
    paddingHorizontal: Spacing.four,
  },
  centerText: { textAlign: 'center' },
});

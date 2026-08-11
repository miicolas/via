import { GlassView } from 'expo-glass-effect';
import { useRef } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { MapStatus } from '@/components/map/map-status';
import { MetroMap, type MetroMapHandle } from '@/components/map/metro-map';
import { RouteSelector } from '@/components/map/route-selector';
import { RouteSummary } from '@/components/map/route-summary';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { BottomTabInset, Spacing } from '@/constants/theme';
import { useMetroNetwork } from '@/hooks/use-metro-network';

/** Keeps a fitted line clear of the controls this screen floats over the map. */
const MAP_EDGE_PADDING = { top: 190, right: 24, bottom: 165, left: 24 };

export function MetroMapScreen() {
  const mapRef = useRef<MetroMapHandle>(null);
  const { state, select, retry } = useMetroNetwork();
  const line = state.status === 'ready' ? state.line : undefined;

  return (
    <ThemedView style={styles.container}>
      <MetroMap
        ref={mapRef}
        lines={state.status === 'ready' ? state.lines : []}
        line={line}
        edgePadding={MAP_EDGE_PADDING}
      />

      <SafeAreaView style={styles.overlay} pointerEvents="box-none">
        <View style={styles.topControls} pointerEvents="box-none">
          {state.status === 'ready' && (
            <>
              <RouteSummary line={state.line} />
              <RouteSelector
                routes={state.lines}
                selectedRouteId={state.line.route.id}
                onSelect={select}
              />
            </>
          )}
        </View>

        <View style={styles.actions} pointerEvents="box-none">
          <GlassView glassEffectStyle="clear" isInteractive style={styles.actionGlass}>
            <Pressable
              accessibilityLabel={
                line ? `Recentrer sur toute la ligne ${line.route.shortName}` : 'Recentrer sur le métro'
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

      {state.status !== 'ready' && <MapStatus state={state} onRetry={retry} />}
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
});

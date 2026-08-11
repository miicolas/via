import { GlassView } from 'expo-glass-effect';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Pressable, StyleSheet, View, type LayoutChangeEvent } from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';

import { MapStatus } from '@/components/map/map-status';
import { MetroMap, type MetroMapHandle } from '@/components/map/metro-map';
import { RouteSelector } from '@/components/map/route-selector';
import { RouteSummary } from '@/components/map/route-summary';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { BottomTabInset, Spacing } from '@/constants/theme';
import { useMetroNetwork } from '@/hooks/use-metro-network';

/** Breathing room between a fitted line and whatever floats over it. */
const FRAMING_MARGIN = Spacing.three;

export function MetroMapScreen() {
  const mapRef = useRef<MetroMapHandle>(null);
  const insets = useSafeAreaInsets();
  const { state, select, retry } = useMetroNetwork();
  const line = state.status === 'ready' ? state.line : undefined;

  /**
   * Measured rather than hard-coded.
   *
   * These used to be `{ top: 190, bottom: 165 }`, numbers that described the
   * heights of RouteSummary, RouteSelector and the actions row — defined in three
   * other stylesheets. Changing the selector's height silently mis-framed the
   * camera, with no type and no test to notice. Each cluster now reports its own
   * height, so the knowledge stays where the decision is made.
   */
  const [topHeight, setTopHeight] = useState(0);
  const [actionsHeight, setActionsHeight] = useState(0);
  const measureTop = useCallback((event: LayoutChangeEvent) => {
    setTopHeight(event.nativeEvent.layout.height);
  }, []);
  const measureActions = useCallback((event: LayoutChangeEvent) => {
    setActionsHeight(event.nativeEvent.layout.height);
  }, []);

  const edgePadding = useMemo(
    () => ({
      top: insets.top + Spacing.three + topHeight + FRAMING_MARGIN,
      right: Spacing.three,
      bottom: BottomTabInset + Spacing.three + actionsHeight + FRAMING_MARGIN,
      left: Spacing.three,
    }),
    [actionsHeight, insets.top, topHeight]
  );

  /**
   * Both moments the camera moves are stated here, in the module that decides
   * them. The map used to own one of them as an internal effect while the button
   * reached in through a ref, so one action had two owners and neither file told
   * the whole story.
   *
   * The first frame waits on three independent things — the native map, the
   * network, and the overlay measurement — so it stays an effect with a guard.
   * The guard now protects exactly one thing, "frame a given line once", instead
   * of also standing in for "was this render a new selection?".
   */
  const [mapReady, setMapReady] = useState(false);
  const framedRouteId = useRef<string>(undefined);
  const measured = topHeight > 0;

  useEffect(() => {
    if (!mapReady || !measured || !line) return;
    if (framedRouteId.current === line.route.id) return;
    const animated = framedRouteId.current !== undefined;
    framedRouteId.current = line.route.id;
    mapRef.current?.fitToRoute(line.route, { animated });
  }, [line, mapReady, measured]);

  return (
    <ThemedView style={styles.container}>
      <MetroMap
        ref={mapRef}
        lines={state.status === 'ready' ? state.lines : []}
        line={line}
        edgePadding={edgePadding}
        onReady={() => setMapReady(true)}
      />

      <SafeAreaView style={styles.overlay} pointerEvents="box-none">
        <View style={styles.topControls} onLayout={measureTop} pointerEvents="box-none">
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

        <View style={styles.actions} onLayout={measureActions} pointerEvents="box-none">
          <GlassView glassEffectStyle="clear" isInteractive style={styles.actionGlass}>
            <Pressable
              accessibilityLabel={
                line ? `Recentrer sur toute la ligne ${line.route.shortName}` : 'Recentrer sur le métro'
              }
              accessibilityRole="button"
              hitSlop={8}
              onPress={() => line && mapRef.current?.fitToRoute(line.route, { animated: true })}
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

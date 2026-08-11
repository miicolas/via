import { GlassView } from 'expo-glass-effect';
import { type InferResponseType } from 'hono/client';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Animated, Platform, Pressable, StyleSheet, View } from 'react-native';
import MapView, { MarkerAnimated, Polyline, type LatLng, type Region } from 'react-native-maps';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { BottomTabInset, Spacing } from '@/constants/theme';
import { api, apiBaseUrl } from '@/lib/api';

const LINE_ONE_ID = 'IDFM:C01371';
const LINE_ONE_MAP_COLOR = '#E5AC00';
const STATION_FADE_OUT_DELTA = 0.14;
const STATION_FADE_IN_DELTA = 0.06;
const INITIAL_REGION: Region = {
  latitude: 48.8683,
  longitude: 2.338,
  latitudeDelta: 0.13,
  longitudeDelta: 0.29,
};

const getRouteMap = api.api.routes[':routeId'].map.$get;
type RouteMapData = InferResponseType<typeof getRouteMap, 200>;

export default function MapScreen() {
  const mapRef = useRef<MapView>(null);
  const hasFittedLine = useRef(false);
  const [stationOpacity] = useState(() => new Animated.Value(0));
  const [data, setData] = useState<RouteMapData>();
  const [mapReady, setMapReady] = useState(false);
  const [error, setError] = useState<string>();
  const [requestKey, setRequestKey] = useState(0);

  useEffect(() => {
    let cancelled = false;

    async function loadLine() {
      setError(undefined);
      try {
        const response = await getRouteMap({ param: { routeId: LINE_ONE_ID } });
        if (!response.ok) throw new Error(`API ${response.status}`);
        const body = await response.json();
        if (!cancelled) setData(body);
      } catch (cause) {
        console.error(`[map] Failed to load line 1 from ${apiBaseUrl}`, cause);
        if (!cancelled) setError('La ligne 1 ne peut pas être chargée pour le moment.');
      }
    }

    loadLine();
    return () => {
      cancelled = true;
    };
  }, [requestKey]);

  const lineCoordinates = useMemo<LatLng[]>(
    () =>
      data?.line.coordinates.map(({ latitude, longitude }) => ({ latitude, longitude })) ?? [],
    [data]
  );

  const fitLine = useCallback(
    (animated = true) => {
      if (lineCoordinates.length === 0) return;
      mapRef.current?.fitToCoordinates(lineCoordinates, {
        animated,
        edgePadding: { top: 115, right: 20, bottom: 150, left: 20 },
      });
    },
    [lineCoordinates]
  );

  useEffect(() => {
    if (!mapReady || hasFittedLine.current || lineCoordinates.length === 0) return;
    hasFittedLine.current = true;
    requestAnimationFrame(() => fitLine(false));
  }, [fitLine, lineCoordinates.length, mapReady]);

  const handleRegionChange = useCallback(
    (region: Region) => {
      const progress =
        (STATION_FADE_OUT_DELTA - region.longitudeDelta) /
        (STATION_FADE_OUT_DELTA - STATION_FADE_IN_DELTA);
      stationOpacity.setValue(Math.max(0, Math.min(1, progress)));
    },
    [stationOpacity]
  );

  if (Platform.OS !== 'ios') {
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
      <MapView
        ref={mapRef}
        style={styles.map}
        initialRegion={INITIAL_REGION}
        mapType="standard"
        loadingEnabled
        loadingBackgroundColor="#F5F4EF"
        loadingIndicatorColor="#1D1D1F"
        pitchEnabled={false}
        rotateEnabled={false}
        showsBuildings
        showsCompass={false}
        showsIndoors={false}
        showsPointsOfInterests={false}
        showsTraffic={false}
        showsUserLocation={false}
        onMapReady={() => setMapReady(true)}
        onRegionChange={handleRegionChange}
      >
        {lineCoordinates.length > 0 && (
          <>
            <Polyline
              coordinates={lineCoordinates}
              lineCap="round"
              lineJoin="round"
              strokeColor="rgba(255,255,255,0.9)"
              strokeWidth={4.75}
            />
            <Polyline
              coordinates={lineCoordinates}
              lineCap="round"
              lineJoin="round"
              strokeColor={LINE_ONE_MAP_COLOR}
              strokeWidth={2.75}
            />
          </>
        )}

        {data?.stations.map((station) => (
          <MarkerAnimated
            key={station.id}
            coordinate={{ latitude: station.latitude, longitude: station.longitude }}
            centerOffset={{ x: 0, y: 0 }}
            opacity={stationOpacity}
          >
            <View style={styles.stationDot} />
          </MarkerAnimated>
        ))}
      </MapView>

      <SafeAreaView style={styles.overlay} pointerEvents="box-none">
        <GlassView
          glassEffectStyle="clear"
          style={styles.summary}
          accessible
          accessibilityLabel="Ligne 1 du métro"
        >
          <View style={[styles.lineBadge, { backgroundColor: data?.route.color ?? '#FFBE00' }]}>
            <ThemedText type="smallBold" style={styles.lineBadgeText}>
              1
            </ThemedText>
          </View>
          <View style={styles.summaryText}>
            <ThemedText type="smallBold">Ligne 1</ThemedText>
            <ThemedText type="small" themeColor="textSecondary" numberOfLines={1}>
              {data
                ? `La Défense — Château de Vincennes · ${data.stations.length} stations`
                : 'Chargement du tracé…'}
            </ThemedText>
          </View>
        </GlassView>

        <View style={styles.actions} pointerEvents="box-none">
          <GlassView glassEffectStyle="clear" isInteractive style={styles.actionGlass}>
            <Pressable
              accessibilityLabel="Recentrer sur toute la ligne 1"
              accessibilityRole="button"
              hitSlop={8}
              onPress={() => fitLine(true)}
              style={({ pressed }) => [styles.action, pressed && styles.pressed]}
            >
              <ThemedText type="smallBold">Recentrer</ThemedText>
            </Pressable>
          </GlassView>
        </View>
      </SafeAreaView>

      {!data && (
        <View style={styles.status} accessibilityLiveRegion="polite">
          {error ? (
            <>
              <ThemedText style={styles.centerText}>{error}</ThemedText>
              <Pressable
                accessibilityRole="button"
                onPress={() => setRequestKey((value) => value + 1)}
                style={({ pressed }) => [styles.retry, pressed && styles.pressed]}
              >
                <ThemedText type="smallBold">Réessayer</ThemedText>
              </Pressable>
            </>
          ) : (
            <>
              <ActivityIndicator color="#1D1D1F" />
              <ThemedText type="small">Chargement de la ligne 1…</ThemedText>
            </>
          )}
        </View>
      )}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  map: { flex: 1 },
  overlay: {
    position: 'absolute',
    inset: 0,
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.three,
    paddingTop: Spacing.three,
    paddingBottom: BottomTabInset + Spacing.three,
  },
  summary: {
    alignSelf: 'flex-start',
    maxWidth: 330,
    minHeight: 54,
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.two,
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 18,
  },
  lineBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  lineBadgeText: { color: '#000000' },
  stationDot: {
    width: 7,
    height: 7,
    borderRadius: 3.5,
    backgroundColor: LINE_ONE_MAP_COLOR,
  },
  summaryText: { flex: 1, gap: Spacing.half },
  actions: { alignSelf: 'flex-end' },
  actionGlass: { borderRadius: 22, overflow: 'hidden' },
  action: {
    minHeight: 44,
    justifyContent: 'center',
    paddingHorizontal: Spacing.three,
    borderRadius: 22,
  },
  pressed: { opacity: 0.6 },
  status: {
    position: 'absolute',
    top: '45%',
    alignSelf: 'center',
    minWidth: 220,
    alignItems: 'center',
    gap: Spacing.two,
    padding: Spacing.three,
    borderRadius: 16,
    backgroundColor: 'rgba(255,255,255,0.96)',
  },
  retry: {
    minHeight: 44,
    justifyContent: 'center',
    paddingHorizontal: Spacing.three,
    borderRadius: 22,
    backgroundColor: '#FFBE00',
  },
  unsupported: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.two,
    paddingHorizontal: Spacing.four,
  },
  centerText: { textAlign: 'center' },
});

import type { NetworkRoute } from '@via/contract';
import { useRef, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { DepartureRow } from '@/features/home-map/components/departure-row';
import { ScrollFadeMask } from '@/features/home-map/components/scroll-fade-mask';
import { useDepartures } from '@/features/home-map/hooks/use-departures';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';
import { departureRows } from '@/features/home-map/model/departure-rows';
import type { StationFocus } from '@/features/home-map/model/types';
import { useNow } from '@/hooks/use-now';

type HomeStationSectionProps = {
  routes: NetworkRoute[];
  station: StationFocus;
};

export function HomeStationSection({ routes, station }: HomeStationSectionProps) {
  const { colors } = useHomeMapTheme();
  const departures = useDepartures(station.station.id);
  const now = useNow();
  const [scrolled, setScrolled] = useState(false);
  const scrolledRef = useRef(false);

  const updateScrollFade = (offsetY: number) => {
    const nextScrolled = offsetY > 2;
    if (nextScrolled === scrolledRef.current) return;
    scrolledRef.current = nextScrolled;
    setScrolled(nextScrolled);
  };

  const walkingMinutes = station.distanceMeters
    ? Math.max(1, Math.round(station.distanceMeters / 80))
    : undefined;

  const source = departures.status === 'ready' ? departures.response.source : 'unavailable';
  const groups = departures.status === 'ready' ? departures.response.groups : [];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text numberOfLines={1} style={[styles.stationName, { color: colors.ink }]}>
          {station.station.name}
        </Text>
        <Text style={[styles.walkingTime, { color: colors.muted }]}>
          {walkingMinutes ? `${walkingMinutes} min à pied` : 'station sélectionnée'}
        </Text>
      </View>

      <ScrollFadeMask active={scrolled}>
        <ScrollView
          automaticallyAdjustContentInsets={false}
          contentContainerStyle={styles.departuresContent}
          contentInsetAdjustmentBehavior="never"
          fadingEdgeLength={{ start: 44, end: 0 }}
          onScroll={({ nativeEvent }) => updateScrollFade(nativeEvent.contentOffset.y)}
          scrollEventThrottle={16}
          style={styles.departures}
        >
          {departureRows(routes, groups, now).map((row) => (
            <DepartureRow
              key={row.key}
              route={row.route}
              destination={row.destination}
              wait={row.wait}
              source={source}
            />
          ))}
        </ScrollView>
      </ScrollFadeMask>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    minHeight: 60,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 16,
    paddingHorizontal: 20,
    paddingTop: 8,
  },
  stationName: {
    flex: 1,
    fontFamily: 'Archivo_800ExtraBold',
    fontSize: 22,
    lineHeight: 26,
    letterSpacing: -0.6,
  },
  walkingTime: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    lineHeight: 18,
  },
  departures: { flex: 1 },
  departuresContent: { paddingBottom: 24 },
});

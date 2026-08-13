import type { NetworkRoute } from '@via/contract';
import { useRef, useState } from 'react';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { DepartureRow } from '@/features/home-map/components/departure-row';
import { SCROLL_FADE_HEIGHT } from '@/features/home-map/components/scroll-fade-edge';
import { ScrollFadeMask } from '@/features/home-map/components/scroll-fade-mask';
import { StationDeparturesEmptyState } from '@/features/home-map/components/station-departures-empty-state';
import { useDepartures } from '@/features/home-map/hooks/use-departures';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';
import { departureRows } from '@/features/home-map/model/departure-rows';
import type { StationFocus } from '@/features/home-map/model/types';
import { walkingMinutes } from '@/features/home-map/model/walking-time';
import { useNow } from '@/hooks/use-now';

const SCROLL_FADE_EPSILON = 2;

type HomeStationSectionProps = {
  expanded: boolean;
  routes: NetworkRoute[];
  station: StationFocus;
};

export function HomeStationSection({ expanded, routes, station }: HomeStationSectionProps) {
  const { colors } = useHomeMapTheme();
  const departures = useDepartures(station.station.id);
  const now = useNow();
  const [fade, setFade] = useState({ bottom: false, top: false });
  const metricsRef = useRef({ contentHeight: 0, offsetY: 0, viewportHeight: 0 });

  const syncScrollFade = () => {
    const { contentHeight, offsetY, viewportHeight } = metricsRef.current;
    const bottom = offsetY + viewportHeight < contentHeight - SCROLL_FADE_EPSILON;
    const top = offsetY > SCROLL_FADE_EPSILON;

    // Same object when nothing moved: React bails out instead of re-rendering the list.
    setFade((current) =>
      current.bottom === bottom && current.top === top ? current : { bottom, top }
    );
  };

  const minutes = walkingMinutes(station.distanceMeters);

  const source = departures.status === 'ready' ? departures.response.source : 'unavailable';
  const groups = departures.status === 'ready' ? departures.response.groups : [];
  const rows = departureRows(routes, groups, now);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text numberOfLines={1} style={[styles.stationName, { color: colors.ink }]}>
          {station.station.name}
        </Text>
        <Text style={[styles.walkingTime, { color: colors.muted }]}>
          {minutes ? `${minutes} min à pied` : 'station sélectionnée'}
        </Text>
      </View>

      {departures.status === 'ready' && rows.length === 0 ? (
        <StationDeparturesEmptyState expanded={expanded} />
      ) : (
        <ScrollFadeMask bottom={fade.bottom} top={fade.top}>
          <ScrollView
            automaticallyAdjustContentInsets={false}
            contentContainerStyle={styles.departuresContent}
            contentInsetAdjustmentBehavior="never"
            fadingEdgeLength={{ start: SCROLL_FADE_HEIGHT, end: SCROLL_FADE_HEIGHT }}
            onContentSizeChange={(_width, height) => {
              metricsRef.current.contentHeight = height;
              syncScrollFade();
            }}
            onLayout={({ nativeEvent }) => {
              metricsRef.current.viewportHeight = nativeEvent.layout.height;
              syncScrollFade();
            }}
            onScroll={({ nativeEvent }) => {
              metricsRef.current = {
                contentHeight: nativeEvent.contentSize.height,
                offsetY: nativeEvent.contentOffset.y,
                viewportHeight: nativeEvent.layoutMeasurement.height,
              };
              syncScrollFade();
            }}
            scrollEventThrottle={16}
            style={styles.departures}
          >
            {rows.map((row) => (
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
      )}
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

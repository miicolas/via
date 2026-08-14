import { StyleSheet, Text, View } from 'react-native';

import { FadingScrollView } from '@/components/fading-scroll-view';
import { DepartureRow } from '@/features/departures/components/row';
import { ListRowSkeleton } from '@/components/list-row-skeleton';
import { StationDeparturesEmptyState } from '@/features/departures/components/empty-state';
import { useDepartures } from '@/features/departures/hooks/use-departures';
import { useAppTheme } from '@/hooks/use-app-theme';
import { departureRows } from '@/features/departures/model/rows';
import type { StationFocus } from '@/features/map/model/types';
import { walkingMinutes } from '@/features/journey/model/walking-time';
import { useNow } from '@/hooks/use-now';
import { SHEET_GUTTER } from '@/styles/metrics';

type StationSectionProps = {
  expanded: boolean;
  station: StationFocus;
};

export function StationSection({ expanded, station }: StationSectionProps) {
  const { colors } = useAppTheme();
  const departures = useDepartures(station.station.id);
  const now = useNow();
  const minutes = walkingMinutes(station.distanceMeters);

  const source = departures.status === 'ready' ? departures.response.source : 'unavailable';
  const groups = departures.status === 'ready' ? departures.response.groups : [];
  const rows = departureRows(groups, now);

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

      {departures.status !== 'ready' ? (
        <View style={styles.departuresContent}>
          <ListRowSkeleton count={expanded ? 4 : 2} leadingSize={30} rowHeight={92} trailingWidth={46} />
        </View>
      ) : rows.length === 0 ? (
        <StationDeparturesEmptyState expanded={expanded} />
      ) : (
        <FadingScrollView
          automaticallyAdjustContentInsets={false}
          contentContainerStyle={styles.departuresContent}
          contentInsetAdjustmentBehavior="never"
          style={styles.departures}
        >
          {rows.map((row) => (
            <DepartureRow
              directions={row.directions}
              key={row.key}
              route={row.route}
              source={source}
            />
          ))}
        </FadingScrollView>
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
    paddingHorizontal: SHEET_GUTTER,
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

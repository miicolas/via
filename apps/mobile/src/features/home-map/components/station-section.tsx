import type { NetworkRoute } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { DepartureRow } from '@/features/home-map/components/departure-row';
import { useDepartures } from '@/features/home-map/hooks/use-departures';
import { departureRows } from '@/features/home-map/model/departure-rows';
import type { StationFocus } from '@/features/home-map/model/types';
import { waitTimes } from '@/features/home-map/model/wait-times';
import { HomeMapTheme } from '@/features/home-map/styles/theme';
import { useNow } from '@/hooks/use-now';

type HomeStationSectionProps = {
  routes: NetworkRoute[];
  station: StationFocus;
};

export function HomeStationSection({ routes, station }: HomeStationSectionProps) {
  const departures = useDepartures(station.station.id);
  const now = useNow();

  const walkingMinutes = station.distanceMeters
    ? Math.max(1, Math.round(station.distanceMeters / 80))
    : undefined;

  const source = departures.status === 'ready' ? departures.response.source : 'unavailable';
  const groups = departures.status === 'ready' ? departures.response.groups : [];

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text numberOfLines={1} style={styles.stationName}>
          {station.station.name}
        </Text>
        <Text style={styles.walkingTime}>
          {walkingMinutes ? `${walkingMinutes} min à pied` : 'station sélectionnée'}
        </Text>
      </View>

      <View style={styles.departures}>
        {departureRows(routes, groups).map((row) => (
          <DepartureRow
            key={row.key}
            route={row.route}
            destination={row.destination}
            wait={row.departures ? waitTimes(row.departures, now) : undefined}
            source={source}
          />
        ))}
      </View>
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
    color: HomeMapTheme.ink,
    fontFamily: 'Archivo_800ExtraBold',
    fontSize: 22,
    lineHeight: 26,
    letterSpacing: -0.6,
  },
  walkingTime: {
    color: HomeMapTheme.muted,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    lineHeight: 18,
  },
  departures: { flex: 1 },
});

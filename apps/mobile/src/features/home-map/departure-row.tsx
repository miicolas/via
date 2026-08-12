import type { NetworkRoute } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { HomeMapTheme } from '@/features/home-map/theme';

type DepartureRowProps = {
  route: NetworkRoute;
};

export function DepartureRow({ route }: DepartureRowProps) {
  return (
    <View style={styles.row}>
      <LineBadge route={route} size={50} />
      <Text numberOfLines={2} style={styles.destination}>
        {route.destinations?.[0] ?? route.longName}
      </Text>
      <View style={styles.timing}>
        <View style={styles.primaryTiming}>
          <Text style={styles.minutes}>—</Text>
          <Text style={styles.unit}>min</Text>
        </View>
        <Text style={styles.following}>temps réel indisponible</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 92,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginHorizontal: 20,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#161A181F',
  },
  destination: {
    flex: 1,
    minWidth: 0,
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 18,
    lineHeight: 22,
  },
  timing: { alignItems: 'flex-end' },
  primaryTiming: { flexDirection: 'row', alignItems: 'baseline', gap: 2 },
  minutes: {
    color: HomeMapTheme.ink,
    fontFamily: 'Archivo_900Black',
    fontSize: 38,
    lineHeight: 42,
    letterSpacing: -1.5,
  },
  unit: {
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
  },
  following: {
    maxWidth: 100,
    color: HomeMapTheme.muted,
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    lineHeight: 14,
  },
});

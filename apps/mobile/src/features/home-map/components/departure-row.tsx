import type { DeparturesSource, NetworkRoute } from '@via/contract';
import { SymbolView, type AnimationSpec } from 'expo-symbols';
import { StyleSheet, Text, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { departureQualifier } from '@/features/home-map/model/departure-qualifier';
import type { WaitTimes } from '@/features/home-map/model/wait-times';
import { HomeMapTheme } from '@/features/home-map/styles/theme';

const LIVE_SYMBOL_ANIMATION: AnimationSpec = {
  effect: { type: 'bounce' },
  repeating: true,
};

type DepartureRowProps = {
  route: NetworkRoute;
  /** Absent while loading or when no departure is announced for this line. */
  destination?: string;
  wait?: WaitTimes;
  source: DeparturesSource;
};

export function DepartureRow({ route, destination, wait, source }: DepartureRowProps) {
  return (
    <View style={styles.row}>
      <LineBadge route={route} size={50} />
      <Text numberOfLines={2} style={styles.destination}>
        {destination ?? route.destinations?.[0] ?? route.longName}
      </Text>
      <View style={styles.timing}>
        <View style={styles.primaryTiming}>
          {source === 'realtime' && wait ? (
            <SymbolView
              animationSpec={LIVE_SYMBOL_ANIMATION}
              name="wave.3.left"
              size={13}
              tintColor={HomeMapTheme.primary}
              weight="semibold"
            />
          ) : null}
          <Text style={styles.minutes}>{wait ? String(wait.primaryMinutes) : '—'}</Text>
          <Text style={styles.unit}>min</Text>
        </View>
        <Text style={styles.following}>{departureQualifier(source, wait)}</Text>
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
    textAlign: 'right',
  },
});

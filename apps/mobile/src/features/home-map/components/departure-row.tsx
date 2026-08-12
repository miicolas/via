import type { DeparturesSource, NetworkRoute } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { LineBadge } from '@/components/map/line-badge';
import { LiveSymbol } from '@/components/live-symbol';
import { AnimatedMinutes } from '@/features/home-map/components/animated-minutes';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';
import { departureQualifier } from '@/features/home-map/model/departure-qualifier';
import type { WaitTimes } from '@/features/home-map/model/wait-times';

type DepartureRowProps = {
  route: NetworkRoute;
  destination: string;
  wait: WaitTimes;
  source: DeparturesSource;
};

export function DepartureRow({ route, destination, wait, source }: DepartureRowProps) {
  const { colors } = useHomeMapTheme();

  return (
    <View style={[styles.row, { borderBottomColor: colors.line }]}>
      <LineBadge route={route} size={50} />
      <Text numberOfLines={2} style={[styles.destination, { color: colors.ink }]}>
        {destination}
      </Text>
      <View style={styles.timing}>
        <View style={styles.primaryTiming}>
          {source === 'realtime' ? (
            <LiveSymbol color={colors.primary} name="wave.3.left" size={13} />
          ) : null}
          <AnimatedMinutes color={colors.ink} value={wait.primaryMinutes} />
          <Text style={[styles.unit, { color: colors.ink }]}>min</Text>
        </View>
        <Text style={[styles.following, { color: colors.muted }]}>
          {departureQualifier(source, wait)}
        </Text>
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
  },
  destination: {
    flex: 1,
    minWidth: 0,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 18,
    lineHeight: 22,
  },
  timing: { alignItems: 'flex-end' },
  primaryTiming: { flexDirection: 'row', alignItems: 'baseline', gap: 2 },
  unit: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
  },
  following: {
    maxWidth: 100,
    fontFamily: 'Inter_400Regular',
    fontSize: 11,
    lineHeight: 14,
    textAlign: 'right',
  },
});

import { StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { AnimatedMinutes } from '@/features/departures/components/animated-minutes';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyDepartureCountdownProps = {
  minutes: number;
  realtime: boolean;
};

export function JourneyDepartureCountdown({ minutes, realtime }: JourneyDepartureCountdownProps) {
  const { colors } = useAppTheme();
  const accessibilityLabel =
    minutes > 0
      ? `Pars d’ici dans ${minutes} minutes${realtime ? ', horaire en direct' : ''}`
      : `Pars maintenant${realtime ? ', horaire en direct' : ''}`;

  return (
    <View
      accessible
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="text"
      style={styles.countdown}
    >
      <Text
        accessible={false}
        numberOfLines={1}
        style={[styles.label, { color: colors.ink }]}
      >
        {minutes > 0 ? 'Pars d’ici dans' : 'Pars maintenant'}
      </Text>
      {minutes > 0 ? (
        <View style={styles.timing}>
          {realtime ? (
            <SymbolIcon
              animation="pulse"
              color={colors.primary}
              name="wave.3.left"
              replayIntervalMs={10_000}
              size={13}
            />
          ) : null}
          <AnimatedMinutes color={colors.ink} value={minutes} />
          <Text accessible={false} style={[styles.unit, { color: colors.ink }]}>
            min
          </Text>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  countdown: {
    minWidth: 0,
    flexShrink: 1,
    alignItems: 'flex-end',
    gap: 1,
  },
  timing: { flexDirection: 'row', alignItems: 'center', gap: 2 },
  label: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
    lineHeight: 18,
  },
  unit: { fontFamily: 'Inter_600SemiBold', fontSize: 14 },
});

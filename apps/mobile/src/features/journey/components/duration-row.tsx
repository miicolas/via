import { StyleSheet, Text, View } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';
import { formatTime } from '@/lib/format-time';

/** Every total shares one lane so the durations line up down the list. */
export const DURATION_COLUMN_WIDTH = 74;

type JourneyDurationRowProps = {
  /** Shown under the total: the list is ordered by this, not by duration. */
  arrivalAt: string;
  minutes: number;
  /** Strikes through and mutes a route the network reports as disrupted. */
  struck?: boolean;
};

/** An alternative's total, over the arrival time that explains its rank. */
export function JourneyDurationRow({ arrivalAt, minutes, struck = false }: JourneyDurationRowProps) {
  const { colors } = useAppTheme();
  const arrival = formatTime(arrivalAt);

  return (
    <View
      accessible
      accessibilityLabel={`${minutes} minutes, arrivée à ${arrival}`}
      accessibilityRole="text"
      style={styles.block}>
      <Text
        accessible={false}
        style={[styles.total, { color: struck ? colors.muted : colors.ink }, struck && styles.struck]}>
        {minutes} min
      </Text>
      <Text accessible={false} style={[styles.arrival, { color: colors.muted }]}>
        → {arrival}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  block: {
    width: DURATION_COLUMN_WIDTH,
    flexShrink: 0,
    alignItems: 'flex-end',
    gap: 1,
  },
  total: {
    fontFamily: 'Archivo_700Bold',
    fontSize: 18,
    lineHeight: 22,
    letterSpacing: -0.36,
    textAlign: 'right',
    fontVariant: ['tabular-nums'],
  },
  struck: { textDecorationLine: 'line-through' },
  arrival: {
    fontFamily: 'Inter_500Medium',
    fontSize: 12,
    lineHeight: 15,
    textAlign: 'right',
    fontVariant: ['tabular-nums'],
  },
});

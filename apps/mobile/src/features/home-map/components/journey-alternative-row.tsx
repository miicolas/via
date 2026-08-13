import type { Journey } from '@via/contract';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { JourneyLegStrip } from '@/features/home-map/components/journey-leg-strip';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type JourneyAlternativeRowProps = {
  journey: Journey;
  onPress: () => void;
};

export function JourneyAlternativeRow({ journey, onPress }: JourneyAlternativeRowProps) {
  const { colors } = useHomeMapTheme();
  const duration = Math.max(1, Math.round(journey.durationSeconds / 60));
  const warning = journey.warnings[0];

  return (
    <Pressable
      accessibilityLabel={`Itinéraire alternatif de ${duration} minutes`}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.row,
        { borderBottomColor: colors.line },
        pressed && styles.pressed,
      ]}>
      <View style={styles.summary}>
        <JourneyLegStrip compact journey={journey} />
        <Text selectable style={[styles.duration, { color: colors.ink }]}>
          {duration} min
        </Text>
      </View>
      {warning ? (
        <Text numberOfLines={2} selectable style={[styles.warning, { color: colors.critical }]}>
          {warning}
        </Text>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 69,
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  summary: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  duration: {
    minWidth: 70,
    fontFamily: 'Inter_700Bold',
    fontSize: 18,
    lineHeight: 23,
    textAlign: 'right',
    textDecorationLine: 'none',
    fontVariant: ['tabular-nums'],
  },
  warning: {
    fontFamily: 'Inter_500Medium',
    fontSize: 13,
    lineHeight: 17,
  },
  pressed: { opacity: 0.55 },
});

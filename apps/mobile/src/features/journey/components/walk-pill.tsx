import { StyleSheet, Text } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { JourneyLegPill } from '@/features/journey/components/leg-pill';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyWalkPillProps = {
  minutes: number;
};

/** A stretch on foot, kept quiet so the lines around it carry the row. */
export function JourneyWalkPill({ minutes }: JourneyWalkPillProps) {
  const { colors } = useAppTheme();

  return (
    <JourneyLegPill background={colors.track}>
      <SymbolIcon color={colors.muted} name="figure.walk" size={13} />
      <Text style={[styles.minutes, { color: colors.muted }]}>{minutes}</Text>
    </JourneyLegPill>
  );
}

const styles = StyleSheet.create({
  minutes: {
    fontFamily: 'Inter_500Medium',
    fontSize: 14,
    fontVariant: ['tabular-nums'],
  },
});

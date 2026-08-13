import { StyleSheet, Text, View } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyDurationHeroProps = {
  minutes: number;
};

/** The headline total of the recommended journey, number split from its unit. */
export function JourneyDurationHero({ minutes }: JourneyDurationHeroProps) {
  const { colors } = useAppTheme();

  return (
    <View
      accessible
      accessibilityLabel={`${minutes} minutes`}
      accessibilityRole="text"
      style={styles.hero}>
      <Text accessible={false} style={[styles.value, { color: colors.ink }]}>
        {minutes}
      </Text>
      <Text accessible={false} style={[styles.unit, { color: colors.muted }]}>
        min
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: {
    flexShrink: 0,
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 4,
  },
  value: {
    fontFamily: 'Archivo_900Black',
    fontSize: 42,
    lineHeight: 42,
    letterSpacing: -1.68,
    fontVariant: ['tabular-nums'],
  },
  unit: {
    fontFamily: 'Inter_500Medium',
    fontSize: 14,
    lineHeight: 18,
  },
});

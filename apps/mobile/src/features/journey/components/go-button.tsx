import { Pressable, StyleSheet, Text } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';

type JourneyGoButtonProps = {
  accessibilityLabel: string;
  /** Stretches the pill across its row, for the detail footer. Default hugs content. */
  grow?: boolean;
  onPress: () => void;
};

/** The single committing action of the results screen. */
export function JourneyGoButton({ accessibilityLabel, grow = false, onPress }: JourneyGoButtonProps) {
  const { colors } = useAppTheme();

  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        grow && styles.grow,
        { backgroundColor: colors.primary },
        pressed && styles.pressed,
      ]}>
      <SymbolIcon
        animation={{ effect: { type: 'bounce', direction: 'up' } }}
        color={colors.surface}
        name="paperplane.fill"
        size={15}
      />
      <Text style={[styles.label, { color: colors.surface }]}>Voir l’itinéraire</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    minHeight: 44,
    flexShrink: 0,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 7,
    paddingHorizontal: 18,
    borderRadius: 999,
    borderCurve: 'continuous',
  },
  label: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 15,
    lineHeight: 18,
    letterSpacing: -0.15,
  },
  grow: { flexGrow: 1, flexBasis: 0 },
  pressed: { opacity: 0.65 },
});

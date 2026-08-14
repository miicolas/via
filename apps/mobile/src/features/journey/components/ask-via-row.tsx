import { Pressable, StyleSheet, Text } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';

type AskViaRowProps = {
  onPress: () => void;
};

/** The way out of the computed list and into a question asked in plain words. */
export function AskViaRow({ onPress }: AskViaRowProps) {
  const { colors } = useAppTheme();

  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
      <SymbolIcon animation="pulse" color={colors.primary} name="sparkles" size={14} />
      <Text style={[styles.label, { color: colors.primary }]}>Demander autrement à Via</Text>
      <SymbolIcon color={colors.primary} name="chevron.right" size={14} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingVertical: 16,
  },
  label: {
    minWidth: 0,
    flex: 1,
    fontFamily: 'Inter_500Medium',
    fontSize: 16,
    lineHeight: 20,
    letterSpacing: -0.16,
  },
  pressed: { opacity: 0.55 },
});

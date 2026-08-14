import { router } from 'expo-router';
import { Pressable, StyleSheet, Text } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';

/** Opens the Via conversation to follow up on the shown journeys. */
export function AskViaRow() {
  const { colors } = useAppTheme();

  return (
    <Pressable
      accessibilityRole="button"
      onPress={() => router.push('/chat')}
      style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
      <SymbolIcon color={colors.primary} name="sparkles" size={14} />
      <Text style={[styles.label, { color: colors.ink }]}>Demander autrement à Via</Text>
      <SymbolIcon color={colors.muted} name="chevron.right" size={12} />
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
  pressed: { opacity: 0.7 },
});

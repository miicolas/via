import { StyleSheet, Pressable, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';

type ViaAnswerActionsProps = {
  onGo?: () => void;
  onReply: () => void;
};

/** The card's two follow-ups: launch the journey, or keep talking to Via. */
export function ViaAnswerActions({ onGo, onReply }: ViaAnswerActionsProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.row}>
      {onGo ? (
        <Pressable
          accessibilityRole="button"
          onPress={onGo}
          style={({ pressed }) => [
            styles.pill,
            { backgroundColor: colors.primary },
            pressed && styles.pressed,
          ]}>
          <SymbolIcon color={colors.surface} name="location.fill" size={13} />
          <Text style={[styles.label, { color: colors.surface }]}>Voir l’itinéraire</Text>
        </Pressable>
      ) : null}
      <Pressable
        accessibilityRole="button"
        onPress={onReply}
        style={({ pressed }) => [
          styles.pill,
          styles.outline,
          { borderColor: colors.line },
          pressed && styles.pressed,
        ]}>
        <SymbolIcon color={colors.ink} name="bubble.left" size={13} />
        <Text style={[styles.label, { color: colors.ink }]}>Répondre</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', flexWrap: 'wrap', gap: 10, paddingTop: 4 },
  pill: {
    minHeight: 46,
    flexGrow: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingHorizontal: 20,
    borderRadius: 23,
    borderCurve: 'continuous',
  },
  outline: { borderWidth: 1 },
  label: { fontFamily: 'Inter_600SemiBold', fontSize: 15 },
  pressed: { opacity: 0.7 },
});

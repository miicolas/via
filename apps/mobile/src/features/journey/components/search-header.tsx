import { Pressable, StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneySearchHeaderProps = {
  destination: string;
  onCancel: () => void;
};

export function JourneySearchHeader({ destination, onCancel }: JourneySearchHeaderProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.container}>
      <Pressable
        accessibilityHint="Revient à la recherche"
        accessibilityLabel={`Destination ${destination}`}
        accessibilityRole="button"
        onPress={onCancel}
        style={({ pressed }) => [
          styles.search,
          {
            backgroundColor: colors.surfaceGlass,
            borderColor: colors.hairline,
            boxShadow: `0 2px 8px ${colors.shadow}`,
          },
          pressed && styles.pressed,
        ]}>
        <SymbolIcon color={colors.primary} name="magnifyingglass" size={18} weight="regular" />
        <Text numberOfLines={1} style={[styles.destination, { color: colors.ink }]}>
          {destination}
        </Text>
        <View style={[styles.clear, { backgroundColor: colors.control }]}>
          <SymbolIcon color={colors.surface} name="xmark" size={10} weight="bold" />
        </View>
      </Pressable>

      <Pressable
        accessibilityRole="button"
        hitSlop={8}
        onPress={onCancel}
        style={({ pressed }) => [styles.cancel, pressed && styles.pressed]}>
        <Text style={[styles.cancelLabel, { color: colors.primary }]}>Annuler</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: SHEET_GUTTER,
    paddingTop: 4,
    paddingBottom: 10,
  },
  search: {
    minWidth: 0,
    height: 50,
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 16,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 999,
    borderCurve: 'continuous',
  },
  destination: {
    minWidth: 0,
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 16,
    lineHeight: 20,
    letterSpacing: -0.16,
  },
  clear: {
    width: 20,
    height: 20,
    flexShrink: 0,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 10,
  },
  cancel: {
    minHeight: 44,
    justifyContent: 'center',
  },
  cancelLabel: {
    fontFamily: 'Inter_500Medium',
    fontSize: 16,
    lineHeight: 20,
  },
  pressed: { opacity: 0.55 },
});

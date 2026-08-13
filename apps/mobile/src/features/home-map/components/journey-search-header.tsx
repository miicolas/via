import { Pressable, StyleSheet, Text, View } from 'react-native';

import { SymbolIcon } from '@/components/symbol-icon';
import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type JourneySearchHeaderProps = {
  destination: string;
  onCancel: () => void;
};

export function JourneySearchHeader({ destination, onCancel }: JourneySearchHeaderProps) {
  const { colors } = useHomeMapTheme();

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
            backgroundColor: colors.surface,
            boxShadow: `0 1px 8px ${colors.shadow}`,
          },
          pressed && styles.pressed,
        ]}>
        <SymbolIcon color={colors.primary} name="magnifyingglass" size={19} weight="regular" />
        <Text numberOfLines={1} style={[styles.destination, { color: colors.ink }]}>
          {destination}
        </Text>
        <View style={[styles.clear, { backgroundColor: colors.control }]}>
          <SymbolIcon color={colors.surface} name="xmark" size={11} weight="bold" />
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
    paddingHorizontal: 16,
    paddingTop: 4,
    paddingBottom: 12,
  },
  search: {
    minWidth: 0,
    height: 52,
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 18,
    borderRadius: 26,
    borderCurve: 'continuous',
  },
  destination: {
    minWidth: 0,
    flex: 1,
    fontFamily: 'Inter_400Regular',
    fontSize: 17,
    lineHeight: 22,
  },
  clear: {
    width: 22,
    height: 22,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 11,
  },
  cancel: {
    minHeight: 44,
    justifyContent: 'center',
  },
  cancelLabel: {
    fontFamily: 'Inter_500Medium',
    fontSize: 17,
  },
  pressed: { opacity: 0.55 },
});

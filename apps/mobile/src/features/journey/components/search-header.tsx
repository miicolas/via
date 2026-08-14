import { Pressable, StyleSheet, Text, View } from 'react-native';

import { GlassIconButton } from '@/components/glass-icon-button';
import { SymbolIcon } from '@/components/symbol-icon';
import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type JourneySearchHeaderProps = {
  destination: string;
  onCancel: () => void;
  onBack?: () => void;
};

export function JourneySearchHeader({ destination, onBack, onCancel }: JourneySearchHeaderProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.container}>
      {onBack ? (
        <GlassIconButton accessibilityLabel="Retour aux itinéraires" onPress={onBack}>
          <SymbolIcon color={colors.ink} name="chevron.left" size={19} />
        </GlassIconButton>
      ) : null}

      <Pressable
        accessibilityHint="Annule la recherche et revient à ta localisation"
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
  pressed: { opacity: 0.55 },
});

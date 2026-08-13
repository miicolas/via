import type { AddressSearchResult } from '@via/contract';
import { SymbolIcon } from '@/components/symbol-icon';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { formatDistance } from '@/lib/format-distance';
import { useAppTheme } from '@/hooks/use-app-theme';

type AddressResultRowProps = {
  onPress: () => void;
  result: AddressSearchResult;
};

export function AddressResultRow({ onPress, result }: AddressResultRowProps) {
  const { colors } = useAppTheme();

  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.row,
        { borderBottomColor: colors.line },
        pressed && styles.pressed,
      ]}>
      <SymbolIcon color={colors.muted} name="mappin.circle.fill" size={30} />
      <View style={styles.copy}>
        <Text numberOfLines={1} style={[styles.name, { color: colors.ink }]}>
          {result.name}
        </Text>
        <Text numberOfLines={1} style={[styles.context, { color: colors.muted }]}>
          {result.context}
        </Text>
      </View>
      {result.distanceMeters !== undefined ? (
        <Text style={[styles.distance, { color: colors.muted }]}>
          {formatDistance(result.distanceMeters)}
        </Text>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    minHeight: 64,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  copy: { flex: 1, gap: 2 },
  name: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    lineHeight: 21,
  },
  context: {
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
  },
  distance: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
  },
  pressed: { opacity: 0.5 },
});

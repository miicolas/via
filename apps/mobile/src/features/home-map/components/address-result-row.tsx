import type { AddressSearchResult } from '@via/contract';
import { SymbolView } from 'expo-symbols';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { formatDistance } from '@/features/home-map/model/format-distance';
import { HomeMapTheme } from '@/features/home-map/styles/theme';

type AddressResultRowProps = {
  onPress: () => void;
  result: AddressSearchResult;
};

export function AddressResultRow({ onPress, result }: AddressResultRowProps) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.row, pressed && styles.pressed]}>
      <SymbolView name="mappin.circle.fill" size={30} tintColor={HomeMapTheme.muted} />
      <View style={styles.copy}>
        <Text numberOfLines={1} style={styles.name}>
          {result.name}
        </Text>
        <Text numberOfLines={1} style={styles.context}>
          {result.context}
        </Text>
      </View>
      {result.distanceMeters !== undefined ? (
        <Text style={styles.distance}>{formatDistance(result.distanceMeters)}</Text>
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
    borderBottomColor: '#161A181F',
  },
  copy: { flex: 1, gap: 2 },
  name: {
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 17,
    lineHeight: 21,
  },
  context: {
    color: HomeMapTheme.muted,
    fontFamily: 'Inter_400Regular',
    fontSize: 13,
  },
  distance: {
    color: HomeMapTheme.muted,
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
  },
  pressed: { opacity: 0.5 },
});

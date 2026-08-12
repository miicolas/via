import { SymbolView, type SFSymbol } from 'expo-symbols';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { HomeMapTheme } from '@/features/home-map/styles/theme';

type ShortcutsProps = {
  onClose: () => void;
  onLocate: () => void;
  walkingMinutes?: number;
};

export function Shortcuts({ onClose, onLocate, walkingMinutes }: ShortcutsProps) {
  const items: {
    icon: SFSymbol;
    label: string;
    onPress: () => void;
    value: string;
  }[] = [
    {
      icon: 'location.fill',
      label: 'Ma position',
      onPress: onLocate,
      value: walkingMinutes ? `${walkingMinutes} min` : 'Actualiser',
    },
    { icon: 'map.fill', label: 'Carte', onPress: onClose, value: 'Ouvrir' },
  ];

  return (
    <View style={styles.content}>
      {items.map((item) => (
        <Pressable
          accessibilityRole="button"
          key={item.label}
          onPress={item.onPress}
          style={({ pressed }) => [styles.shortcut, pressed && styles.pressed]}>
          <SymbolView name={item.icon} size={14} tintColor={HomeMapTheme.primary} />
          <Text style={styles.label}>{item.label}</Text>
          <Text style={styles.value}>{item.value}</Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  content: { flexDirection: 'row', gap: 8, paddingHorizontal: 20 },
  shortcut: {
    minHeight: 40,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 12,
    borderRadius: 20,
    borderCurve: 'continuous',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#161A1810',
    backgroundColor: '#FFFFFFB8',
    boxShadow: '0 1px 4px rgba(22, 26, 24, 0.05)',
  },
  label: {
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    lineHeight: 17,
  },
  value: {
    color: HomeMapTheme.primary,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    lineHeight: 16,
  },
  pressed: { opacity: 0.55 },
});

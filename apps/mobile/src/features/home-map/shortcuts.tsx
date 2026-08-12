import { SymbolView, type SFSymbol } from 'expo-symbols';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { HomeMapTheme } from '@/features/home-map/theme';

type ShortcutsProps = {
  lineCount: number;
  onClose: () => void;
  onLocate: () => void;
  walkingMinutes?: number;
};

export function Shortcuts({ lineCount, onClose, onLocate, walkingMinutes }: ShortcutsProps) {
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
    {
      icon: 'tram.fill',
      label: 'Réseau',
      onPress: onClose,
      value: `${lineCount} ligne${lineCount > 1 ? 's' : ''}`,
    },
  ];

  return (
    <ScrollView
      contentContainerStyle={styles.content}
      horizontal
      style={styles.scroll}
      showsHorizontalScrollIndicator={false}>
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
      <View style={styles.endSpace} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scroll: { flexGrow: 0, height: 44 },
  content: { alignItems: 'center', gap: 10, paddingHorizontal: 20 },
  shortcut: {
    minHeight: 44,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 7,
    paddingHorizontal: 14,
    borderRadius: 22,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#161A1814',
    backgroundColor: '#FFFFFFD9',
  },
  label: {
    color: HomeMapTheme.ink,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 14,
  },
  value: {
    color: HomeMapTheme.primary,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
  },
  pressed: { opacity: 0.55 },
  endSpace: { width: 10 },
});

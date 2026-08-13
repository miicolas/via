import { type SFSymbol } from 'expo-symbols';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Symbol } from '@/components/symbol';

import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type ShortcutsProps = {
  onClose: () => void;
  onLocate: () => void;
  onHouse: () => void;
  walkingMinutes?: number;
};

export function Shortcuts({ onClose, onLocate, onHouse, walkingMinutes }: ShortcutsProps) {
  const { colors } = useHomeMapTheme();
  const items: {
    icon: SFSymbol;
    label: string;
    onPress: () => void;
    value: string | null ;
  }[] = [


    {
      icon: 'house.fill',
      label: 'Rentrer chez moi',
      onPress: onHouse,
      value: walkingMinutes ? `${walkingMinutes} min` : null,
    },
    {
      icon: 'work.fill',
      label: 'Rentrer chez moi',
      onPress: onHouse,
      value: walkingMinutes ? `${walkingMinutes} min` : null,
    },
  ];

  return (
    <View style={styles.content}>
      {items.map((item) => (
        <Pressable
          accessibilityRole="button"
          key={item.label}
          onPress={item.onPress}
          style={({ pressed }) => [
            styles.shortcut,
            {
              backgroundColor: colors.surfaceTranslucent,
              borderColor: colors.line,
              boxShadow: `0 1px 4px ${colors.shadow}`,
            },
            pressed && styles.pressed,
          ]}>
          <Symbol color={colors.primary} name={item.icon} size={13} />
          <Text style={[styles.label, { color: colors.ink }]}>{item.label}</Text>
          <Text style={[styles.value, { color: colors.primary }]}>{item.value}</Text>
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
  },
  label: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    lineHeight: 17,
  },
  value: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    lineHeight: 16,
  },
  pressed: { opacity: 0.55 },
});

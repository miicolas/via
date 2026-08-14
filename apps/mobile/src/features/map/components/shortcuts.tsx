import { type SFSymbol } from 'expo-symbols';
import { StyleSheet, Text, View } from 'react-native';
import { Button } from '@/components/button';
import { SymbolIcon } from '@/components/symbol-icon';

import { useAppTheme } from '@/hooks/use-app-theme';
import { SHEET_GUTTER } from '@/styles/metrics';

type ShortcutsProps = {
  onClose: () => void;
  onLocate: () => void;
  onHouse?: () => void;
  onWork?: () => void;
  walkingMinutes?: number;
};

export function Shortcuts({ onClose, onLocate, onHouse, onWork, walkingMinutes }: ShortcutsProps) {
  const { colors } = useAppTheme();
  const items: {
    icon: SFSymbol;
    label: string;
    onPress: () => void;
    value: string | null ;
  }[] = [
    ...(onHouse ? [{
      icon: 'house.fill' as SFSymbol,
      label: 'Rentrer chez moi',
      onPress: onHouse,
      value: walkingMinutes ? `${walkingMinutes} min` : null,
    }] : []),
    ...(onWork ? [{
      icon: 'briefcase.fill' as SFSymbol,
      label: 'Boulot',
      onPress: onWork,
      value: null,
    }] : []),
  ];

  return (
    <View style={styles.content}>
      {items.map((item) => (
        <Button
          contentStyle={[
            styles.shortcut,
            {
              backgroundColor: colors.surfaceGlass,
              borderColor: colors.line,
              boxShadow: `0 1px 4px ${colors.shadow}`,
            },
          ]}
          key={item.label}
          label={item.label}
          onPress={item.onPress}
          variant="plain">
          <SymbolIcon color={colors.primary} name={item.icon} size={13} />
          <Text style={[styles.label, { color: colors.ink }]}>{item.label}</Text>
          <Text style={[styles.value, { color: colors.primary }]}>{item.value}</Text>
        </Button>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  content: { flexDirection: 'row', gap: 8, paddingHorizontal: SHEET_GUTTER },
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
});

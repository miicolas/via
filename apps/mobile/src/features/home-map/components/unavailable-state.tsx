import { SymbolView, type SFSymbol } from 'expo-symbols';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useHomeMapTheme } from '@/features/home-map/hooks/use-home-map-theme';

type HomeUnavailableStateProps = {
  actionLabel?: string;
  description: string;
  icon: SFSymbol;
  onAction?: () => void;
  title: string;
};

export function HomeUnavailableState({
  actionLabel,
  description,
  icon,
  onAction,
  title,
}: HomeUnavailableStateProps) {
  const { colors } = useHomeMapTheme();

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <View
          style={[
            styles.iconBadge,
            {
              backgroundColor: colors.accentSoft,
              boxShadow: `0 1px 3px ${colors.shadow}`,
            },
          ]}>
          <SymbolView name={icon} size={30} tintColor={colors.primary} weight="semibold" />
        </View>

        <View style={styles.copy}>
          <Text selectable style={[styles.title, { color: colors.ink }]}>
            {title}
          </Text>
          <Text selectable style={[styles.description, { color: colors.muted }]}>
            {description}
          </Text>
        </View>

        {actionLabel && onAction ? (
          <Pressable
            accessibilityRole="button"
            onPress={onAction}
            style={({ pressed }) => [
              styles.action,
              {
                backgroundColor: colors.primary,
                boxShadow: `0 2px 6px ${colors.shadow}`,
              },
              pressed && styles.pressed,
            ]}>
            <Text style={[styles.actionLabel, { color: colors.surface }]}>{actionLabel}</Text>
          </Pressable>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
    paddingVertical: 32,
  },
  content: {
    alignItems: 'center',
    alignSelf: 'center',
    gap: 18,
    maxWidth: 330,
    width: '100%',
  },
  iconBadge: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 68,
    height: 68,
    borderRadius: 34,
  },
  copy: {
    alignItems: 'center',
    gap: 6,
  },
  title: {
    fontFamily: 'Archivo_800ExtraBold',
    fontSize: 23,
    lineHeight: 28,
    letterSpacing: -0.5,
    textAlign: 'center',
  },
  description: {
    maxWidth: 300,
    fontFamily: 'Inter_400Regular',
    fontSize: 15,
    lineHeight: 21,
    textAlign: 'center',
  },
  action: {
    minHeight: 48,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 22,
    borderRadius: 24,
    borderCurve: 'continuous',
  },
  actionLabel: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 16,
    lineHeight: 20,
  },
  pressed: {
    opacity: 0.82,
    transform: [{ scale: 0.97 }],
  },
});

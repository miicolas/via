import {
  GlassView,
  isGlassEffectAPIAvailable,
  isLiquidGlassAvailable,
} from 'expo-glass-effect';
import type { ReactNode } from 'react';
import { Pressable, StyleSheet, type StyleProp, type ViewStyle } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

const GLASS_AVAILABLE = isLiquidGlassAvailable() && isGlassEffectAPIAvailable();

type GlassIconButtonProps = {
  accessibilityLabel: string;
  onPress: () => void;
  children: ReactNode;
  size?: number;
  style?: StyleProp<ViewStyle>;
};

/** A round icon button: interactive Liquid Glass where iOS offers it, tinted where it does not. */
export function GlassIconButton({
  accessibilityLabel,
  children,
  onPress,
  size = 44,
  style,
}: GlassIconButtonProps) {
  const { colorScheme, colors } = useAppTheme();
  const frame = { width: size, height: size, borderRadius: size / 2 };

  if (!GLASS_AVAILABLE) {
    return (
      <Pressable
        accessibilityLabel={accessibilityLabel}
        accessibilityRole="button"
        onPress={onPress}
        style={({ pressed }) => [
          styles.button,
          frame,
          {
            backgroundColor: colors.surfaceGlass,
            borderColor: colors.hairline,
            borderWidth: StyleSheet.hairlineWidth,
          },
          pressed && styles.pressed,
          style,
        ]}>
        {children}
      </Pressable>
    );
  }

  return (
    <GlassView colorScheme={colorScheme} isInteractive style={[styles.button, frame, style]}>
      <Pressable
        accessibilityLabel={accessibilityLabel}
        accessibilityRole="button"
        onPress={onPress}
        style={[styles.press, frame]}>
        {children}
      </Pressable>
    </GlassView>
  );
}

const styles = StyleSheet.create({
  button: {
    flexShrink: 0,
    alignItems: 'center',
    justifyContent: 'center',
    borderCurve: 'continuous',
    overflow: 'hidden',
  },
  press: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  pressed: { opacity: 0.55 },
});

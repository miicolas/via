import { GlassView } from 'expo-glass-effect';
import type { PropsWithChildren } from 'react';
import { StyleSheet, type StyleProp, type ViewProps, type ViewStyle } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';
import { SURFACE_GLASS_EFFECT_STYLE } from '@/styles/app-theme';

type GlassSurfaceProps = PropsWithChildren<
  Omit<ViewProps, 'style'> & {
    style?: StyleProp<ViewStyle>;
    variant?: 'card' | 'control' | 'tinted';
    tintColor?: string | null;
  }
>;

/** The single material boundary for every React Native Liquid Glass surface. */
export function GlassSurface({
  children,
  style,
  tintColor,
  variant = 'card',
  ...props
}: GlassSurfaceProps) {
  const { colorScheme, colors } = useAppTheme();
  const resolvedTint = tintColor === null ? undefined : (tintColor ?? colors.surfaceGlass);
  const frame = [
    variant === 'card' && styles.card,
    variant !== 'tinted' && {
      borderColor: colors.hairline,
      borderWidth: StyleSheet.hairlineWidth,
    },
    variant === 'card' && { boxShadow: `0 2px 10px ${colors.shadow}` },
    style,
  ];

  return (
    <GlassView
      {...props}
      colorScheme={colorScheme}
      glassEffectStyle={SURFACE_GLASS_EFFECT_STYLE}
      isInteractive={variant === 'control'}
      style={frame}
      tintColor={resolvedTint}>
      {children}
    </GlassView>
  );
}

const styles = StyleSheet.create({
  card: {
    gap: 14,
    paddingVertical: 16,
    paddingHorizontal: 18,
    borderRadius: 24,
    borderCurve: 'continuous',
  },
});

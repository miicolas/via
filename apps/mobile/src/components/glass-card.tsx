import { GlassView, isLiquidGlassAvailable } from 'expo-glass-effect';
import type { ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

const GLASS_AVAILABLE = isLiquidGlassAvailable();

type GlassCardProps = {
  children: ReactNode;
};

/** The raised surface of the sheet: Liquid Glass where iOS offers it, tinted where it does not. */
export function GlassCard({ children }: GlassCardProps) {
  const { colorScheme, colors } = useAppTheme();
  const frame = [
    styles.card,
    { borderColor: colors.hairline, boxShadow: `0 2px 10px ${colors.shadow}` },
  ];

  if (!GLASS_AVAILABLE) {
    return <View style={[frame, { backgroundColor: colors.surfaceGlass }]}>{children}</View>;
  }

  return (
    <GlassView colorScheme={colorScheme} glassEffectStyle="clear" style={frame}>
      {children}
    </GlassView>
  );
}

const styles = StyleSheet.create({
  card: {
    gap: 14,
    paddingVertical: 16,
    paddingHorizontal: 18,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 24,
    borderCurve: 'continuous',
  },
});

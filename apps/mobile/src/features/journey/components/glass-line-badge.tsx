import { GlassView, isLiquidGlassAvailable } from 'expo-glass-effect';
import { StyleSheet, Text, View } from 'react-native';

import type { LineBadgeRoute } from '@/components/map/line-badge';
import { transitBadgeFrame } from '@/components/map/transit-badge-shape';

const GLASS_AVAILABLE = isLiquidGlassAvailable();

type GlassLineBadgeProps = {
  route: LineBadgeRoute;
  size: number;
};

/**
 * The line's logo as Liquid Glass, for surfaces that already wear the line's colour —
 * a solid badge there is either invisible or a hard stamp. Same frame as LineBadge,
 * so the mode still reads from the shape; a translucent tint stands in off-iOS.
 */
export function GlassLineBadge({ route, size }: GlassLineBadgeProps) {
  const frame = [
    styles.badge,
    transitBadgeFrame(route.mode, size),
    { paddingHorizontal: route.mode === 'bus' ? 6 : 0 },
  ];
  const label = (
    <Text
      style={[
        styles.label,
        { color: route.textColor, fontSize: size * 0.5, lineHeight: size * 0.58 },
      ]}>
      {route.shortName}
    </Text>
  );

  if (!GLASS_AVAILABLE) {
    return <View style={[frame, { backgroundColor: `${route.textColor}2E` }]}>{label}</View>;
  }

  return (
    <GlassView glassEffectStyle="clear" style={frame}>
      {label}
    </GlassView>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignItems: 'center',
    justifyContent: 'center',
    borderCurve: 'continuous',
    overflow: 'hidden',
  },
  label: { fontFamily: 'Archivo_800ExtraBold', letterSpacing: -0.5 },
});

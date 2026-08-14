import type { NetworkRoute } from '@via/contract';
import {
  GlassView,
  isGlassEffectAPIAvailable,
  isLiquidGlassAvailable,
} from 'expo-glass-effect';
import { StyleSheet, Text, View } from 'react-native';

import { transitBadgeFrame } from '@/components/map/transit-badge-shape';
import { isNearWhite } from '@/lib/is-near-white';
import { withAlpha } from '@/lib/with-alpha';

export type LineBadgeRoute = Pick<NetworkRoute, 'mode' | 'color' | 'textColor' | 'shortName'>;

const GLASS_AVAILABLE = isLiquidGlassAvailable() && isGlassEffectAPIAvailable();

type LineBadgeProps = {
  /** `onLine` keeps the glass readable on a pill that already uses the line colour. */
  appearance?: 'line' | 'onLine';
  /**
   * Never undefined: `networkState` only reports `ready` once a line resolves, so
   * the placeholder branch this used to carry is unreachable.
   */
  route: LineBadgeRoute;
  size: number;
};

/** A native Liquid Glass line badge whose shape identifies metro, RER or bus. */
export function LineBadge({ appearance = 'line', route, size }: LineBadgeProps) {
  const onLine = appearance === 'onLine';
  const frame = [
    styles.badge,
    transitBadgeFrame(route.mode, size),
    { paddingHorizontal: route.mode === 'bus' ? 6 : 0 },
    onLine && {
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: withAlpha(route.textColor, 0.38),
    },
    !onLine &&
      isNearWhite(route.color) && { borderWidth: 1.5, borderColor: route.textColor },
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
    const backgroundColor = onLine ? withAlpha(route.textColor, 0.2) : route.color;
    return <View style={[frame, { backgroundColor }]}>{label}</View>;
  }

  return (
    <GlassView
      glassEffectStyle="regular"
      style={frame}
      tintColor={onLine ? undefined : route.color}>
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

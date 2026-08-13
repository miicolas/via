import type { NetworkRoute } from '@via/contract';
import { StyleSheet, Text, View } from 'react-native';

import { transitBadgeFrame } from '@/components/map/transit-badge-shape';

export type LineBadgeRoute = Pick<NetworkRoute, 'mode' | 'color' | 'textColor' | 'shortName'>;

type LineBadgeProps = {
  /**
   * Never undefined: `networkState` only reports `ready` once a line resolves, so
   * the placeholder branch this used to carry is unreachable.
   */
  route: LineBadgeRoute;
  size: number;
};

/** A line badge whose shape identifies metro, RER or bus at a glance. */
export function LineBadge({ route, size }: LineBadgeProps) {
  return (
    <View
      style={[
        styles.badge,
        transitBadgeFrame(route.mode, size),
        {
          backgroundColor: route.color,
          paddingHorizontal: route.mode === 'bus' ? 6 : 0,
        },
      ]}
    >
      <Text
        style={[
          styles.label,
          { color: route.textColor, fontSize: size * 0.5, lineHeight: size * 0.58 },
        ]}>
        {route.shortName}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    alignItems: 'center',
    justifyContent: 'center',
    borderCurve: 'continuous',
  },
  label: { fontFamily: 'Archivo_800ExtraBold', letterSpacing: -0.5 },
});

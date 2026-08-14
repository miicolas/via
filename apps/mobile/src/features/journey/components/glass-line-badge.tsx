import { StyleSheet, Text, View } from 'react-native';

import type { LineBadgeRoute } from '@/components/map/line-badge';
import { transitBadgeFrame } from '@/components/map/transit-badge-shape';
import { withAlpha } from '@/lib/with-alpha';

type GlassLineBadgeProps = {
  route: LineBadgeRoute;
  size: number;
};

/** A translucent fallback for platforms without SwiftUI Liquid Glass. */
export function GlassLineBadge({ route, size }: GlassLineBadgeProps) {
  return (
    <View
      style={[
        styles.badge,
        transitBadgeFrame(route.mode, size),
        { backgroundColor: withAlpha(route.textColor, 0.2) },
      ]}
    >
      <Text
        style={[
          styles.label,
          { color: route.textColor, fontSize: size * 0.5, lineHeight: size * 0.58 },
        ]}
      >
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
    overflow: 'hidden',
  },
  label: { fontFamily: 'Archivo_800ExtraBold', letterSpacing: -0.5 },
});

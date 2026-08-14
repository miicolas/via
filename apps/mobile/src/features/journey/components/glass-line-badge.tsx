import { Host } from '@expo/ui';
import { Text } from '@expo/ui/swift-ui';
import {
  font,
  foregroundStyle,
  frame,
  glassEffect,
  monospacedDigit,
} from '@expo/ui/swift-ui/modifiers';

import type { LineBadgeRoute } from '@/components/map/line-badge';

type GlassLineBadgeProps = {
  route: LineBadgeRoute;
  size: number;
};

/** The route mark rendered as a real SwiftUI Liquid Glass shape. */
export function GlassLineBadge({ route, size }: GlassLineBadgeProps) {
  const isMetro = route.mode === 'metro';
  const width = route.mode === 'bus' ? size * 1.4 : size;

  return (
    <Host matchContents style={{ height: size, minWidth: width }}>
      <Text
        modifiers={[
          font({ size: size * 0.5, weight: 'heavy' }),
          monospacedDigit(),
          foregroundStyle(route.textColor),
          frame({ width, height: size }),
          glassEffect({
            glass: { variant: 'regular' },
            shape: isMetro ? 'circle' : 'roundedRectangle',
            cornerRadius: isMetro ? undefined : size * 0.16,
          }),
        ]}>
        {route.shortName}
      </Text>
    </Host>
  );
}

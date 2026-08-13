import type { StyleProp, ViewStyle } from 'react-native';
import { View } from 'react-native';

import { useAppTheme } from '@/hooks/use-app-theme';

type PulseBlockProps = {
  height: number;
  radius?: number;
  /** Width and flex come from the caller, so one block can stand in for any shape. */
  style?: StyleProp<ViewStyle>;
};

/** One placeholder shape. Wrap a group of them in `PulseGroup` to make them breathe. */
export function PulseBlock({ height, radius = 9, style }: PulseBlockProps) {
  const { colors } = useAppTheme();

  return (
    <View
      style={[
        { height, borderRadius: radius, borderCurve: 'continuous', backgroundColor: colors.track },
        style,
      ]}
    />
  );
}

import type { ReactNode } from 'react';
import { useEffect } from 'react';
import type { StyleProp, ViewStyle } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';

const PULSE_DURATION_MS = 900;
const RESTING_OPACITY = 0.7;

type PulseGroupProps = {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
};

/**
 * Makes a whole placeholder layout breathe on one animation. The blocks never overlap,
 * so fading the group is pixel-identical to fading each block — and a skeleton is on
 * screen exactly when the threads are busiest.
 */
export function PulseGroup({ children, style }: PulseGroupProps) {
  const reduceMotion = useReducedMotion();
  const progress = useSharedValue(RESTING_OPACITY);

  useEffect(() => {
    if (reduceMotion) {
      progress.value = RESTING_OPACITY;
      return;
    }

    progress.value = withRepeat(
      withTiming(1, { duration: PULSE_DURATION_MS, easing: Easing.inOut(Easing.quad) }),
      -1,
      true
    );
  }, [progress, reduceMotion]);

  const pulse = useAnimatedStyle(() => ({ opacity: progress.value }));

  return <Animated.View style={[style, pulse]}>{children}</Animated.View>;
}

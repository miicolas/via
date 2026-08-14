import { useEffect } from 'react';
import type { StyleProp, TextProps, TextStyle } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withDelay,
  withTiming,
} from 'react-native-reanimated';

const ENTER_DURATION_MS = 220;
const REDUCED_MOTION_DURATION_MS = 160;
const ENTER_DISTANCE = 8;
const ENTER_EASING = Easing.bezier(0.23, 1, 0.32, 1);

type AnimatedNumberTextProps = Omit<TextProps, 'children' | 'style'> & {
  delayMs?: number;
  style?: StyleProp<TextStyle>;
  value: number | string;
};

/** Gives changing figures the same short vertical hand-off used by live departures. */
export function AnimatedNumberText({
  delayMs = 0,
  style,
  value,
  ...textProps
}: AnimatedNumberTextProps) {
  const reduceMotion = useReducedMotion();
  const progress = useSharedValue(0);

  useEffect(() => {
    progress.value = 0;
    progress.value = withDelay(
      delayMs,
      withTiming(1, {
        duration: reduceMotion ? REDUCED_MOTION_DURATION_MS : ENTER_DURATION_MS,
        easing: ENTER_EASING,
      })
    );
  }, [delayMs, progress, reduceMotion, value]);

  const animatedStyle = useAnimatedStyle(() => ({
    opacity: progress.value,
    transform: [{ translateY: reduceMotion ? 0 : (1 - progress.value) * ENTER_DISTANCE }],
  }));

  return (
    <Animated.Text {...textProps} style={[style, animatedStyle]}>
      {value}
    </Animated.Text>
  );
}

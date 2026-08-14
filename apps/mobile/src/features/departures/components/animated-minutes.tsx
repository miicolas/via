import { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

const MINUTES_LINE_HEIGHT = 42;
const MINUTES_TRAVEL_DISTANCE = 12;
const TRANSITION_DURATION_MS = 240;
const TRANSITION_EASING = Easing.out(Easing.cubic);

type MinutesTransition = {
  labels: [string, string];
  step: number;
};

type AnimatedMinutesProps = {
  appearance?: 'compact' | 'hero';
  color: string;
  value?: number;
};

export function AnimatedMinutes({ appearance = 'hero', color, value }: AnimatedMinutesProps) {
  const compact = appearance === 'compact';
  const reduceMotion = useReducedMotion();
  const label = value === undefined ? '—' : String(value);
  const [transition, setTransition] = useState<MinutesTransition>(() => ({
    labels: [label, label],
    step: 0,
  }));
  const position = useSharedValue(0);
  const firstSlotStep = useSharedValue(0);
  const secondSlotStep = useSharedValue(1);

  useEffect(() => {
    setTransition((current) => {
      const activeSlot = current.step % 2;
      if (current.labels[activeSlot] === label) return current;

      const step = current.step + 1;
      const nextSlot = step % 2;
      const labels: [string, string] = [...current.labels];
      labels[nextSlot] = label;

      return { labels, step };
    });
  }, [label]);

  useEffect(() => {
    if (transition.step % 2 === 0) {
      firstSlotStep.value = transition.step;
    } else {
      secondSlotStep.value = transition.step;
    }

    position.value = reduceMotion
      ? transition.step
      : withTiming(transition.step, {
          duration: TRANSITION_DURATION_MS,
          easing: TRANSITION_EASING,
        });
  }, [firstSlotStep, position, reduceMotion, secondSlotStep, transition.step]);

  const firstSlotStyle = useAnimatedStyle(() => {
    const distance = Math.max(-1, Math.min(1, position.value - firstSlotStep.value));

    return {
      opacity: 1 - Math.abs(distance),
      transform: [{ translateY: distance * MINUTES_TRAVEL_DISTANCE }],
    };
  });

  const secondSlotStyle = useAnimatedStyle(() => {
    const distance = Math.max(-1, Math.min(1, position.value - secondSlotStep.value));

    return {
      opacity: 1 - Math.abs(distance),
      transform: [{ translateY: distance * MINUTES_TRAVEL_DISTANCE }],
    };
  });

  const measurementLabel =
    transition.labels[0].length >= transition.labels[1].length
      ? transition.labels[0]
      : transition.labels[1];

  return (
    <View
      accessible
      accessibilityLabel={label}
      accessibilityRole="text"
      style={[styles.viewport, compact && styles.compactViewport]}>
      <Text
        accessible={false}
        style={[styles.minutes, compact && styles.compactMinutes, styles.measurement]}>
        {measurementLabel}
      </Text>
      <Animated.Text
        accessible={false}
        style={[
          styles.minutes,
          compact && styles.compactMinutes,
          styles.layer,
          { color },
          firstSlotStyle,
        ]}>
        {transition.labels[0]}
      </Animated.Text>
      <Animated.Text
        accessible={false}
        style={[
          styles.minutes,
          compact && styles.compactMinutes,
          styles.layer,
          { color },
          secondSlotStyle,
        ]}>
        {transition.labels[1]}
      </Animated.Text>
    </View>
  );
}

const styles = StyleSheet.create({
  viewport: {
    position: 'relative',
    height: MINUTES_LINE_HEIGHT,
    minWidth: 20,
    justifyContent: 'center',
    overflow: 'hidden',
  },
  compactViewport: { height: 30, minWidth: 15 },
  minutes: {
    fontFamily: 'Archivo_900Black',
    fontSize: 38,
    fontVariant: ['tabular-nums'],
    lineHeight: MINUTES_LINE_HEIGHT,
    letterSpacing: -1.5,
    textAlign: 'right',
  },
  compactMinutes: {
    fontSize: 27,
    lineHeight: 30,
    letterSpacing: -1,
  },
  measurement: { opacity: 0 },
  layer: { position: 'absolute', top: 0, right: 0 },
});

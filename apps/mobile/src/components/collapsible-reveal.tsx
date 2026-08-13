import type { PropsWithChildren } from 'react';
import { type LayoutChangeEvent, StyleSheet } from 'react-native';
import Animated, {
  Extrapolation,
  interpolate,
  type SharedValue,
  useAnimatedStyle,
  useSharedValue,
} from 'react-native-reanimated';

/** Children only scale — any translation would push them into the clipped edges. */
const REVEAL_START_SCALE = 0.94;
/** The slot opens first so the children only paint once nothing clips them. */
const SLOT_PROGRESS_RANGE = [0, 0.5];
const CONTENT_PROGRESS_RANGE = [0.5, 1];

type CollapsibleRevealProps = PropsWithChildren<{
  /** Drives the reveal, 0 for closed to 1 for fully open. */
  progress: SharedValue<number>;
  /** Space kept above the children, revealed along with them. */
  spacing?: number;
}>;

/** Opens the space its children need, then fades and grows them in once nothing clips them. */
export function CollapsibleReveal({ children, progress, spacing = 0 }: CollapsibleRevealProps) {
  const contentHeight = useSharedValue(0);

  const measureContent = (event: LayoutChangeEvent) => {
    contentHeight.value = event.nativeEvent.layout.height;
  };

  const viewportStyle = useAnimatedStyle(() => ({
    height:
      contentHeight.value *
      interpolate(progress.value, SLOT_PROGRESS_RANGE, [0, 1], Extrapolation.CLAMP),
  }));
  const contentStyle = useAnimatedStyle(() => {
    const shown = interpolate(progress.value, CONTENT_PROGRESS_RANGE, [0, 1], Extrapolation.CLAMP);

    return {
      opacity: shown,
      transform: [{ scale: REVEAL_START_SCALE + (1 - REVEAL_START_SCALE) * shown }],
    };
  });

  return (
    <Animated.View style={[styles.viewport, viewportStyle]}>
      <Animated.View
        onLayout={measureContent}
        style={[styles.content, { paddingTop: spacing }, contentStyle]}>
        {children}
      </Animated.View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  viewport: { overflow: 'hidden' },
  content: { position: 'absolute', top: 0, left: 0, right: 0 },
});

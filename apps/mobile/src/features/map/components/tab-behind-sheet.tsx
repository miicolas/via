/* eslint-disable react-hooks/immutability -- Reanimated shared values are mutable worklet state. */
import {
  GlassView,
  type GlassViewProps,
  isGlassEffectAPIAvailable,
} from 'expo-glass-effect';
import { type PropsWithChildren, useEffect, useMemo } from 'react';
import { type AccessibilityActionEvent, Pressable, StyleSheet, useWindowDimensions, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  cancelAnimation,
  Extrapolation,
  interpolate,
  runOnJS,
  useAnimatedProps,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';

import { useAppTheme } from '@/hooks/use-app-theme';
import { SheetExpansionContext } from '@/features/map/state/sheet-expansion';

const SHEET_HORIZONTAL_INSET = 10;
const SHEET_BOTTOM_INSET = 10;
const COLLAPSED_SHEET_WIDTH = 276;
const HANDLE_HEIGHT = 30;
const HANDLE_VERTICAL_HIT_SLOP = 7;
const TAB_ENVELOPE_DEPTH = 96;
const TAB_CONTENT_CLEARANCE = 90;
const MATERIAL_REVEAL_DISTANCE = 48;
const VELOCITY_PROJECTION_SECONDS = 0.16;
const COLLAPSED_DETENT_INDEX = 0;
const REVEALED_DETENT_INDEX = 1;
const CORNER_RADIUS_ANCHORS = [54, 40, 34]; // collapsed, first revealed, expanded
const CONTENT_FADE_START_OFFSET = 30;
const CONTENT_RISE_DISTANCE = 18;
const GLASS_ACTIVATION_OFFSET = 1;
const SPRING = { damping: 36, mass: 1, overshootClamping: true, stiffness: 360 } as const;
const AnimatedGlassView = Animated.createAnimatedComponent(GlassView);
const GLASS_AVAILABLE = isGlassEffectAPIAvailable();

type TabBehindSheetProps = PropsWithChildren<{
  detentFractions: readonly [number, number, ...number[]]; // collapsed, first revealed, …
  detentIndex: number;
  onDetentChange: (index: number) => void;
  topInset: number;
}>;

export function TabBehindSheet({
  children,
  detentFractions,
  detentIndex,
  onDetentChange,
  topInset,
}: TabBehindSheetProps) {
  const { height: viewportHeight, width: viewportWidth } = useWindowDimensions();
  const { colorScheme, colors } = useAppTheme();
  const reduceMotion = useReducedMotion();
  const availableHeight = Math.max(1, viewportHeight - topInset - SHEET_BOTTOM_INSET);
  const snapHeights = useMemo(
    () => {
      const collapsedHeight = Math.min(TAB_ENVELOPE_DEPTH, availableHeight);

      return detentFractions.map((fraction, index) =>
        index === 0
          ? collapsedHeight
          : Math.max(collapsedHeight, Math.min(availableHeight, availableHeight * fraction))
      );
    },
    [availableHeight, detentFractions]
  );
  const collapsedHeight = snapHeights[0];
  const mediumHeight = snapHeights[1];
  const expandedHeight = snapHeights[snapHeights.length - 1];
  const collapsedHorizontalInset = Math.max(
    SHEET_HORIZONTAL_INSET,
    (viewportWidth - COLLAPSED_SHEET_WIDTH) / 2
  );
  const targetHeight = snapHeights[detentIndex] ?? mediumHeight;
  const visibleHeight = useSharedValue(targetHeight);
  const dragStartHeight = useSharedValue(targetHeight);
  useEffect(() => {
    // Skip the spring when the gesture's own settle animation already landed on the target.
    if (reduceMotion || Math.abs(visibleHeight.value - targetHeight) < 0.5) {
      visibleHeight.value = targetHeight;
      return;
    }
    visibleHeight.value = withSpring(targetHeight, SPRING);
  }, [reduceMotion, targetHeight, visibleHeight]);
  const pan = useMemo(
    () =>
      Gesture.Pan()
        .activeOffsetY([-6, 6])
        .onBegin(() => {
          cancelAnimation(visibleHeight);
          dragStartHeight.value = visibleHeight.value;
        })
        .onUpdate((event) => {
          visibleHeight.value = Math.max(
            collapsedHeight,
            Math.min(expandedHeight, dragStartHeight.value - event.translationY)
          );
        })
        .onEnd((event) => {
          const projectedHeight = Math.max(
            collapsedHeight,
            Math.min(
              expandedHeight,
              visibleHeight.value - event.velocityY * VELOCITY_PROJECTION_SECONDS
            )
          );
          let nextIndex = 0;
          for (let index = 1; index < snapHeights.length; index += 1) {
            if (
              Math.abs(projectedHeight - snapHeights[index]) <
              Math.abs(projectedHeight - snapHeights[nextIndex])
            ) {
              nextIndex = index;
            }
          }
          const target = snapHeights[nextIndex];

          if (reduceMotion) {
            visibleHeight.value = target;
            runOnJS(onDetentChange)(nextIndex);
            return;
          }

          visibleHeight.value = withSpring(
            target,
            { ...SPRING, velocity: -event.velocityY },
            (finished) => {
              if (finished) runOnJS(onDetentChange)(nextIndex);
            }
          );
        }),
    [
      collapsedHeight,
      dragStartHeight,
      expandedHeight,
      onDetentChange,
      reduceMotion,
      snapHeights,
      visibleHeight,
    ]
  );

  const shellStyle = useAnimatedStyle(() => {
    const sheetHorizontalInset = interpolate(
      visibleHeight.value,
      [collapsedHeight, mediumHeight],
      [collapsedHorizontalInset, SHEET_HORIZONTAL_INSET],
      Extrapolation.CLAMP
    );

    return {
      borderRadius: interpolate(
        visibleHeight.value,
        [collapsedHeight, mediumHeight, expandedHeight],
        CORNER_RADIUS_ANCHORS,
        Extrapolation.CLAMP
      ),
      height: visibleHeight.value,
      left: sheetHorizontalInset,
      right: sheetHorizontalInset,
    };
  });
  const contentStyle = useAnimatedStyle(() => {
    const fadeStart = collapsedHeight + CONTENT_FADE_START_OFFSET;

    return {
      opacity: interpolate(
        visibleHeight.value,
        [fadeStart, mediumHeight],
        [0, 1],
        Extrapolation.CLAMP
      ),
      transform: [
        {
          translateY: interpolate(
            visibleHeight.value,
            [fadeStart, mediumHeight],
            [CONTENT_RISE_DISTANCE, 0],
            Extrapolation.CLAMP
          ),
        },
      ],
    };
  });
  const materialStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      visibleHeight.value,
      [collapsedHeight, collapsedHeight + MATERIAL_REVEAL_DISTANCE],
      [0, 1],
      Extrapolation.CLAMP
    ),
  }));
  const expansion = useMemo(
    () => ({ height: visibleHeight, snapHeights }),
    [snapHeights, visibleHeight]
  );
  const glassProps = useAnimatedProps<GlassViewProps>(() => ({
    glassEffectStyle:
      visibleHeight.value > collapsedHeight + GLASS_ACTIVATION_OFFSET
        ? ('regular' as const)
        : ('none' as const),
  }));
  const isCollapsed = detentIndex === COLLAPSED_DETENT_INDEX;
  const toggleDetent = () =>
    onDetentChange(isCollapsed ? REVEALED_DETENT_INDEX : COLLAPSED_DETENT_INDEX);
  const adjustDetent = ({ nativeEvent }: AccessibilityActionEvent) => {
    const offset =
      nativeEvent.actionName === 'increment'
        ? 1
        : nativeEvent.actionName === 'decrement'
          ? -1
          : 0;
    if (offset) {
      onDetentChange(Math.max(0, Math.min(snapHeights.length - 1, detentIndex + offset)));
    }
  };

  return (
    <Animated.View style={[styles.sheet, shellStyle]}>
      <Animated.View pointerEvents="none" style={[StyleSheet.absoluteFill, materialStyle]}>
        {GLASS_AVAILABLE ? (
          <AnimatedGlassView
            animatedProps={glassProps}
            colorScheme={colorScheme}
            pointerEvents="none"
            style={StyleSheet.absoluteFill}
          />
        ) : (
          <View
            pointerEvents="none"
            style={[StyleSheet.absoluteFill, { backgroundColor: colors.surfaceTranslucent }]}
          />
        )}
      </Animated.View>

      <GestureDetector gesture={pan}>
        <Pressable
          accessibilityActions={[{ name: 'increment' }, { name: 'decrement' }]}
          accessibilityHint={isCollapsed ? 'Déplie le panneau' : 'Replie le panneau'}
          accessibilityLabel="Panneau de la carte"
          accessibilityRole="adjustable"
          accessibilityValue={{ min: 0, max: snapHeights.length - 1, now: detentIndex }}
          hitSlop={{
            top: HANDLE_VERTICAL_HIT_SLOP,
            bottom: HANDLE_VERTICAL_HIT_SLOP,
            left: 0,
            right: 0,
          }}
          onAccessibilityAction={adjustDetent}
          onPress={toggleDetent}
          style={styles.handleTarget}>
          <View style={[styles.handle, { backgroundColor: colors.sheetHandle }]} />
        </Pressable>
      </GestureDetector>

      <Animated.View
        pointerEvents={isCollapsed ? 'none' : 'auto'}
        style={[styles.content, contentStyle]}>
        <SheetExpansionContext value={expansion}>{children}</SheetExpansionContext>
      </Animated.View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  sheet: {
    position: 'absolute',
    bottom: SHEET_BOTTOM_INSET,
    zIndex: 20,
    overflow: 'hidden',
    borderCurve: 'continuous',
  },
  handleTarget: {
    height: HANDLE_HEIGHT,
    alignItems: 'center',
    justifyContent: 'flex-start',
    paddingTop: 8,
  },
  handle: {
    width: 46,
    height: 5,
    borderRadius: 3,
  },
  content: {
    position: 'absolute',
    top: HANDLE_HEIGHT,
    right: 0,
    bottom: TAB_CONTENT_CLEARANCE,
    left: 0,
    overflow: 'hidden',
  },
});

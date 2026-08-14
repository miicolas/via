import type { AccessibilityActionEvent } from 'react-native';
import { Pressable, StyleSheet, View } from 'react-native';
import type { PanGesture } from 'react-native-gesture-handler';
import { GestureDetector } from 'react-native-gesture-handler';

const HANDLE_VERTICAL_HIT_SLOP = 7;
const REVEALED_DETENT_OFFSET = 1;

export const SHEET_HANDLE_HEIGHT = 30;

type SheetHandleProps = {
  color: string;
  detentIndex: number;
  gesture: PanGesture;
  maximumDetentIndex: number;
  minimumDetentIndex: number;
  onDetentChange: (index: number) => void;
};

/** The shared drag target and accessible stepper for the map sheet. */
export function SheetHandle({
  color,
  detentIndex,
  gesture,
  maximumDetentIndex,
  minimumDetentIndex,
  onDetentChange,
}: SheetHandleProps) {
  const isAtMinimum = detentIndex <= minimumDetentIndex;
  const toggleDetent = () =>
    onDetentChange(
      isAtMinimum
        ? Math.min(maximumDetentIndex, minimumDetentIndex + REVEALED_DETENT_OFFSET)
        : minimumDetentIndex
    );
  const adjustDetent = ({ nativeEvent }: AccessibilityActionEvent) => {
    const offset =
      nativeEvent.actionName === 'increment'
        ? 1
        : nativeEvent.actionName === 'decrement'
          ? -1
          : 0;
    if (offset) {
      onDetentChange(
        Math.max(minimumDetentIndex, Math.min(maximumDetentIndex, detentIndex + offset))
      );
    }
  };

  return (
    <GestureDetector gesture={gesture}>
      <Pressable
        accessibilityActions={[{ name: 'increment' }, { name: 'decrement' }]}
        accessibilityHint={isAtMinimum ? 'Déplie le panneau' : 'Replie le panneau'}
        accessibilityLabel="Panneau de la carte"
        accessibilityRole="adjustable"
        accessibilityValue={{
          min: minimumDetentIndex,
          max: maximumDetentIndex,
          now: detentIndex,
        }}
        hitSlop={{
          top: HANDLE_VERTICAL_HIT_SLOP,
          bottom: HANDLE_VERTICAL_HIT_SLOP,
          left: 0,
          right: 0,
        }}
        onAccessibilityAction={adjustDetent}
        onPress={toggleDetent}
        style={styles.target}>
        <View style={[styles.handle, { backgroundColor: color }]} />
      </Pressable>
    </GestureDetector>
  );
}

const styles = StyleSheet.create({
  target: {
    height: SHEET_HANDLE_HEIGHT,
    alignItems: 'center',
    justifyContent: 'flex-start',
    paddingTop: 8,
  },
  handle: {
    width: 46,
    height: 5,
    borderRadius: 3,
  },
});

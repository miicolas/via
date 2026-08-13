import { Extrapolation, interpolate, useDerivedValue } from 'react-native-reanimated';

import { useSheetExpansion } from '@/features/map/hooks/use-sheet-expansion';

/** Tracks the sheet travelling between two detents as 0 → 1, live during the drag. */
export function useSheetDetentProgress(fromDetentIndex: number, toDetentIndex: number) {
  const { height, snapHeights } = useSheetExpansion();
  const from = snapHeights[fromDetentIndex];
  const to = snapHeights[toDetentIndex];

  return useDerivedValue(() =>
    interpolate(height.value, [from, to], [0, 1], Extrapolation.CLAMP)
  );
}

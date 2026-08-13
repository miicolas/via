import { createContext } from 'react';
import type { SharedValue } from 'react-native-reanimated';

export type SheetExpansion = {
  /** Live sheet height, written on the UI thread while dragging and settling. */
  height: SharedValue<number>;
  /** Height the sheet rests at for each detent, collapsed → expanded. */
  snapHeights: readonly number[];
};

export const SheetExpansionContext = createContext<SheetExpansion | null>(null);

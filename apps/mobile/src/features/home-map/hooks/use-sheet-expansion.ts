import { use } from 'react';

import { SheetExpansionContext } from '@/features/home-map/state/sheet-expansion';

export function useSheetExpansion() {
  const value = use(SheetExpansionContext);
  if (!value) throw new Error('useSheetExpansion must be used inside TabBehindSheet');
  return value;
}

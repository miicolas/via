import { use } from 'react';

import { MapContext } from '@/features/map/state/context';

export function useMap() {
  const value = use(MapContext);
  if (!value) throw new Error('useMap must be used inside MapProvider');
  return value;
}

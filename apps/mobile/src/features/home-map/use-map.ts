import { use } from 'react';

import { HomeMapContext } from '@/features/home-map/context';

export function useHomeMap() {
  const value = use(HomeMapContext);
  if (!value) throw new Error('useHomeMap must be used inside HomeMapProvider');
  return value;
}

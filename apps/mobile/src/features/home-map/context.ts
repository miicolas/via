import { createContext } from 'react';

import type { HomeMapValue } from '@/features/home-map/types';

export const HomeMapContext = createContext<HomeMapValue | null>(null);

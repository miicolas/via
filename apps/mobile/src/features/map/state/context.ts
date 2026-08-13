import { createContext } from 'react';

import type { MapValue } from '@/features/map/model/types';

export const MapContext = createContext<MapValue | null>(null);

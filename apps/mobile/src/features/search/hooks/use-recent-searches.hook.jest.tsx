import type { SearchResult } from '@via/contract';
import { act, renderHook } from '@testing-library/react-native';

import {
  RECENT_SEARCH_STORAGE_KEY,
} from '@/features/search/model/recent-searches';
import { serializeRecentSearches } from '@/features/search/model/serialize-recent-searches';
import { toRecentSearchSnapshot } from '@/features/search/model/to-recent-search-snapshot';
import { useRecentSearches } from '@/features/search/hooks/use-recent-searches';

jest.mock('expo-sqlite/localStorage/install', () => ({}));

const station: SearchResult = {
  kind: 'station',
  id: 'republique',
  name: 'République',
  coordinate: { latitude: 48.8675, longitude: 2.3638 },
  routes: [
    { id: 'line-5', shortName: '5', mode: 'metro', color: '#FF7E2E', textColor: '#000000' },
  ],
  distanceMeters: 300,
};

const storage = new Map<string, string>();

beforeEach(() => {
  storage.clear();
  Object.defineProperty(globalThis, 'localStorage', {
    configurable: true,
    value: {
      getItem: (key: string) => storage.get(key) ?? null,
      setItem: (key: string, value: string) => void storage.set(key, value),
    },
  });
});

describe('useRecentSearches', () => {
  test('hydrates, promotes and persists a local snapshot', async () => {
    storage.set(
      RECENT_SEARCH_STORAGE_KEY,
      serializeRecentSearches([toRecentSearchSnapshot(station)])
    );

    const { result } = await renderHook(() => useRecentSearches());

    expect(result.current.entries).toEqual([toRecentSearchSnapshot(station)]);

    await act(() => result.current.remember(station));

    expect(result.current.entries).toEqual([toRecentSearchSnapshot(station)]);
    expect(storage.get(RECENT_SEARCH_STORAGE_KEY)).toContain('republique');
    expect(storage.get(RECENT_SEARCH_STORAGE_KEY)).not.toContain('distanceMeters');
  });

  test('removes a snapshot without throwing when persistence is unavailable', async () => {
    const { result } = await renderHook(() => useRecentSearches());
    await act(() => result.current.remember(station));

    Object.defineProperty(globalThis, 'localStorage', {
      configurable: true,
      get: () => {
        throw new Error('storage unavailable');
      },
    });

    await act(() => result.current.remove(result.current.entries[0]!));

    expect(result.current.entries).toEqual([]);
  });
});

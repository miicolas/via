import type { StationsInArea } from '@via/contract';
import { act, renderHook } from '@testing-library/react-native';

import {
  useAreaStations,
  type AreaStationsPort,
} from '@/features/map/hooks/use-area-stations';

jest.mock('@/lib/api', () => ({
  api: { network: { stationsInArea: jest.fn() } },
  apiBaseUrl: 'http://test.invalid',
}));

const markerZoomRegion = {
  latitude: 48.8566,
  longitude: 2.3522,
  latitudeDelta: 0.01,
  longitudeDelta: 0.01,
};

const area = (id: string): StationsInArea => ({
  stations: [
    {
      id,
      name: id,
      coordinate: { latitude: 48.8566, longitude: 2.3522 },
      routeIds: ['bus-38'],
    },
  ],
  routes: [
    { id: 'bus-38', shortName: '38', mode: 'bus', color: '#A66013', textColor: '#FFFFFF' },
  ],
});

function recordingPort(response: StationsInArea) {
  const calls: Array<{ bounds: unknown; signal: AbortSignal }> = [];
  const port: AreaStationsPort = {
    load: (bounds, signal) => {
      calls.push({ bounds, signal });
      return Promise.resolve(response);
    },
  };
  return { calls, port };
}

/** Real timers on purpose: fake timers stall the RN scheduler under jest. */
const settleDebounce = () => act(() => new Promise((resolve) => setTimeout(resolve, 300)));

describe('useAreaStations', () => {
  test('a reported viewport loads its tiles once the debounce settles', async () => {
    const { calls, port } = recordingPort(area('stop'));
    const { result } = await renderHook(() => useAreaStations(port));

    await act(() => {
      result.current.reportViewport(markerZoomRegion);
    });
    expect(calls).toHaveLength(0);

    await settleDebounce();

    expect(calls.length).toBeGreaterThan(0);
    expect(result.current.stations.map(({ id }) => id)).toEqual(['stop']);
    expect(result.current.routes.map(({ id }) => id)).toEqual(['bus-38']);
  });

  test('a zoomed-out viewport fetches nothing', async () => {
    const { calls, port } = recordingPort(area('stop'));
    const { result } = await renderHook(() => useAreaStations(port));

    await act(() => {
      result.current.reportViewport({ ...markerZoomRegion, longitudeDelta: 0.2 });
    });
    await settleDebounce();

    expect(calls).toHaveLength(0);
  });

  test('revisiting the same tiles never refetches them', async () => {
    const { calls, port } = recordingPort(area('stop'));
    const { result } = await renderHook(() => useAreaStations(port));

    await act(() => {
      result.current.reportViewport(markerZoomRegion);
    });
    await settleDebounce();
    const initialCallCount = calls.length;

    await act(() => {
      result.current.reportViewport(markerZoomRegion);
    });
    await settleDebounce();

    expect(calls).toHaveLength(initialCallCount);
  });

  test('ensureArea loads around a point without waiting for a viewport', async () => {
    const { calls, port } = recordingPort(area('stop'));
    const { result } = await renderHook(() => useAreaStations(port));

    await act(async () => {
      result.current.ensureArea({ latitude: 48.8566, longitude: 2.3522 });
    });

    expect(calls.length).toBeGreaterThan(0);
    expect(result.current.stations.map(({ id }) => id)).toEqual(['stop']);
  });

  test('a failed tile is retried on the next viewport report', async () => {
    // The whole first round fails — offline — and the network then comes back.
    let offline = true;
    const calls: unknown[] = [];
    const port: AreaStationsPort = {
      load: () => {
        calls.push(true);
        return offline ? Promise.reject(new Error('offline')) : Promise.resolve(area('stop'));
      },
    };
    const { result } = await renderHook(() => useAreaStations(port));

    await act(() => {
      result.current.reportViewport(markerZoomRegion);
    });
    await settleDebounce();
    expect(result.current.stations).toEqual([]);
    offline = false;

    await act(() => {
      result.current.reportViewport(markerZoomRegion);
    });
    await settleDebounce();

    expect(result.current.stations.map(({ id }) => id)).toEqual(['stop']);
  });
});

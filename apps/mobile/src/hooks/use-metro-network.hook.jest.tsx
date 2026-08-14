import type { NetworkRoute, NetworkStation, RailMap } from '@via/contract';
import { act, renderHook } from '@testing-library/react-native';

import {
  EMPTY_NETWORK_MESSAGE,
  LOAD_FAILED_MESSAGE,
  type NetworkPort,
  useMetroNetwork,
} from '@/hooks/use-metro-network';

jest.mock('@/lib/api', () => ({
  api: { network: { railMap: jest.fn() } },
  apiBaseUrl: 'http://test.invalid',
}));

function route(shortName: string): NetworkRoute {
  return {
    id: `IDFM:${shortName}`,
    shortName,
    color: '#FFCD00',
    textColor: '#000000',
    mode: 'metro',
    segments: [],
  };
}

function station(name: string, routeIds: string[]): NetworkStation {
  return {
    id: `stop-${name}`,
    name,
    coordinate: { latitude: 48.8583, longitude: 2.347 },
    routeIds,
  };
}

const NETWORK: RailMap = {
  routes: [route('4'), route('1')],
  stations: [station('Châtelet', ['IDFM:1', 'IDFM:4'])],
};

type Deferred<T> = {
  promise: Promise<T>;
  reject: (reason?: unknown) => void;
  resolve: (value: T) => void;
};

function deferred<T>(): Deferred<T> {
  let reject!: Deferred<T>['reject'];
  let resolve!: Deferred<T>['resolve'];
  const promise = new Promise<T>((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, reject, resolve };
}

function networkRecorder() {
  const calls: Array<{ request: Deferred<RailMap>; signal: AbortSignal }> = [];
  const port: NetworkPort = {
    load: (signal) => {
      const request = deferred<RailMap>();
      calls.push({ request, signal });
      return request.promise;
    },
  };
  return { calls, port };
}

beforeEach(() => {
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('useMetroNetwork', () => {
  test('loads initially, clears the error on retry and preserves line selection', async () => {
    const recorder = networkRecorder();
    const { result } = await renderHook(() => useMetroNetwork(recorder.port));

    expect(result.current.state).toEqual({ status: 'loading' });
    expect(recorder.calls).toHaveLength(1);

    await act(() => recorder.calls[0]!.request.reject(new Error('network down')));
    expect(result.current.state).toEqual({
      status: 'error',
      message: LOAD_FAILED_MESSAGE,
    });

    await act(() => result.current.select('IDFM:4'));
    await act(() => result.current.retry());
    expect(result.current.state).toEqual({ status: 'loading' });
    expect(recorder.calls).toHaveLength(2);

    await act(() => recorder.calls[1]!.request.resolve(NETWORK));
    expect(result.current.state.status).toBe('ready');
    if (result.current.state.status !== 'ready') return;
    expect(result.current.state.line.route.shortName).toBe('4');
  });

  test('keeps valid network data ahead of a later refresh error', async () => {
    const recorder = networkRecorder();
    const { result } = await renderHook(() => useMetroNetwork(recorder.port));

    await act(() => recorder.calls[0]!.request.resolve(NETWORK));
    await act(() => result.current.retry());
    await act(() => recorder.calls[1]!.request.reject(new Error('refresh failed')));

    expect(result.current.state.status).toBe('ready');
    if (result.current.state.status !== 'ready') return;
    expect(result.current.state.line.route.shortName).toBe('1');
  });

  test('falls back from an invalid selection and treats an empty network as an error', async () => {
    const readyRecorder = networkRecorder();
    const ready = await renderHook(() => useMetroNetwork(readyRecorder.port));

    await act(() => ready.result.current.select('IDFM:unknown'));
    await act(() => readyRecorder.calls[0]!.request.resolve(NETWORK));
    expect(ready.result.current.state.status).toBe('ready');
    if (ready.result.current.state.status === 'ready') {
      expect(ready.result.current.state.line.route.shortName).toBe('1');
    }
    await ready.unmount();

    const emptyRecorder = networkRecorder();
    const empty = await renderHook(() => useMetroNetwork(emptyRecorder.port));
    await act(() => emptyRecorder.calls[0]!.request.resolve({ routes: [], stations: [] }));
    expect(empty.result.current.state).toEqual({
      status: 'error',
      message: EMPTY_NETWORK_MESSAGE,
    });
  });

  test('ignores an aborted error and aborts the current load on unmount', async () => {
    const first = networkRecorder();
    const second = networkRecorder();
    const { result, rerender, unmount } = await renderHook(
      ({ port }: { port: NetworkPort }) => useMetroNetwork(port),
      { initialProps: { port: first.port } }
    );

    await rerender({ port: second.port });
    expect(first.calls[0]!.signal.aborted).toBe(true);
    await act(() => first.calls[0]!.request.reject(new Error('aborted load')));
    expect(result.current.state).toEqual({ status: 'loading' });

    await unmount();
    expect(second.calls[0]!.signal.aborted).toBe(true);
  });
});

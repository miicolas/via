import type { SearchResponse } from '@via/contract';
import { act, renderHook } from '@testing-library/react-native';

import type { UserLocationState } from '@/features/map/model/types';
import { type SearchPort, useSearch } from '@/features/search/hooks/use-search';

jest.mock('@/lib/api', () => ({ api: { search: { query: jest.fn() } } }));

const RESPONSE: SearchResponse = {
  results: [
    {
      kind: 'station',
      id: 'republique',
      name: 'République',
      coordinate: { latitude: 48.8675, longitude: 2.3638 },
      routes: [
        { id: 'line-5', shortName: '5', mode: 'metro', color: '#FF7E2E', textColor: '#000000' },
      ],
    },
  ],
  sources: { ban: 'ok' },
};

const NO_LOCATION: UserLocationState = { status: 'denied' };

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

function searchRecorder() {
  type Input = Parameters<SearchPort['search']>[0];
  const calls: Array<{ input: Input; request: Deferred<SearchResponse>; signal: AbortSignal }> = [];
  const port: SearchPort = {
    search: (input, signal) => {
      const request = deferred<SearchResponse>();
      calls.push({ input, request, signal });
      return request.promise;
    },
  };
  return { calls, port };
}

beforeEach(() => {
  jest.useFakeTimers();
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => {
  jest.useRealTimers();
  jest.restoreAllMocks();
});

describe('useSearch', () => {
  test('keeps an empty query idle without calling the port', async () => {
    const recorder = searchRecorder();
    const { result } = await renderHook(() => useSearch('   ', NO_LOCATION, recorder.port));

    await act(() => jest.advanceTimersByTime(1_000));

    expect(result.current).toEqual({ status: 'idle', results: [], banUnavailable: false });
    expect(recorder.calls).toHaveLength(0);
  });

  test('trims, debounces for 300 ms and rounds the position to four decimals', async () => {
    const recorder = searchRecorder();
    const location: UserLocationState = {
      status: 'ready',
      source: 'device',
      coordinate: { latitude: 48.123456, longitude: 2.987654 },
    };
    const { result } = await renderHook(() => useSearch('  répu  ', location, recorder.port));

    expect(result.current.status).toBe('loading');
    await act(() => jest.advanceTimersByTime(299));
    expect(recorder.calls).toHaveLength(0);

    await act(() => jest.advanceTimersByTime(1));
    expect(recorder.calls[0]?.input).toEqual({
      q: 'répu',
      latitude: 48.1235,
      longitude: 2.9877,
    });

    await act(() => recorder.calls[0]!.request.resolve(RESPONSE));
    expect(result.current).toEqual({
      status: 'ready',
      results: RESPONSE.results,
      banUnavailable: false,
    });
  });

  test('cancels a changed query, keeps the previous result while loading and scopes errors', async () => {
    const recorder = searchRecorder();
    const { result, rerender } = await renderHook(
      ({ query }: { query: string }) => useSearch(query, NO_LOCATION, recorder.port),
      { initialProps: { query: 'répu' } }
    );

    await act(() => jest.advanceTimersByTime(300));
    await act(() => recorder.calls[0]!.request.resolve(RESPONSE));
    expect(result.current.status).toBe('ready');

    await rerender({ query: 'république' });
    expect(recorder.calls[0]!.signal.aborted).toBe(true);
    expect(result.current).toEqual({
      status: 'loading',
      results: RESPONSE.results,
      banUnavailable: false,
    });

    await act(() => jest.advanceTimersByTime(300));
    await act(() => recorder.calls[1]!.request.reject(new Error('new query failed')));
    expect(result.current).toEqual({ status: 'error', results: [], banUnavailable: false });

    await rerender({ query: 'ailleurs' });
    await act(() => jest.advanceTimersByTime(300));
    await rerender({ query: 'encore ailleurs' });
    await act(() => recorder.calls[2]!.request.reject(new Error('cancelled query failed')));
    expect(result.current.status).toBe('loading');
  });

  test('refetches a stable query only when its rounded position changes', async () => {
    const recorder = searchRecorder();
    const location = (latitude: number): UserLocationState => ({
      status: 'ready',
      source: 'device',
      coordinate: { latitude, longitude: 2.35 },
    });
    const { result, rerender } = await renderHook(
      ({ userLocation }: { userLocation: UserLocationState }) =>
        useSearch('répu', userLocation, recorder.port),
      { initialProps: { userLocation: location(48.85001) } }
    );

    await act(() => jest.advanceTimersByTime(300));
    await act(() => recorder.calls[0]!.request.resolve(RESPONSE));

    await rerender({ userLocation: location(48.85002) });
    await act(() => jest.advanceTimersByTime(300));
    expect(recorder.calls).toHaveLength(1);

    await rerender({ userLocation: location(48.85011) });
    expect(result.current.status).toBe('ready');
    await act(() => jest.advanceTimersByTime(300));
    expect(recorder.calls).toHaveLength(2);
    expect(recorder.calls[1]!.input.latitude).toBe(48.8501);
  });

  test('surfaces a degraded address source on the matching response', async () => {
    const recorder = searchRecorder();
    const { result } = await renderHook(() => useSearch('répu', NO_LOCATION, recorder.port));

    await act(() => jest.advanceTimersByTime(300));
    await act(() =>
      recorder.calls[0]!.request.resolve({
        ...RESPONSE,
        sources: { ban: 'unavailable' },
      })
    );

    expect(result.current.banUnavailable).toBe(true);
  });
});

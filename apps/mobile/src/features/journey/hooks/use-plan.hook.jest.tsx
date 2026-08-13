import type { JourneysResponse } from '@via/contract';
import { act, renderHook } from '@testing-library/react-native';

import {
  type JourneyPort,
  useJourneyPlan,
} from '@/features/journey/hooks/use-plan';
import {
  journeyRequestKey,
  type JourneyRequest,
} from '@/features/journey/model/request';

jest.mock('@/lib/api', () => ({ api: { journeys: { plan: jest.fn() } } }));

const RESPONSE: JourneysResponse = {
  status: 'no-route',
  generatedAt: '2026-08-12T18:00:00+02:00',
  journeys: [],
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

function journeyRecorder() {
  type Input = Parameters<JourneyPort['plan']>[0];
  const calls: Array<{ input: Input; request: Deferred<JourneysResponse>; signal: AbortSignal }> = [];
  const port: JourneyPort = {
    plan: (input, signal) => {
      const request = deferred<JourneysResponse>();
      calls.push({ input, request, signal });
      return request.promise;
    },
  };
  return { calls, port };
}

function request(retryGeneration = 0, destinationId = 'republique'): JourneyRequest {
  const origin = { latitude: 48.85, longitude: 2.35 };
  const destination = {
    kind: 'station' as const,
    id: destinationId,
    name: 'République',
    coordinate: { latitude: 48.8675, longitude: 2.3638 },
  };
  return {
    key: journeyRequestKey(origin, destination, retryGeneration),
    origin,
    destination,
  };
}

beforeEach(() => {
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('useJourneyPlan', () => {
  test('is idle without a request and makes no call', async () => {
    const recorder = journeyRecorder();
    const { result } = await renderHook(() => useJourneyPlan(undefined, recorder.port));

    expect(result.current).toEqual({ status: 'idle' });
    expect(recorder.calls).toHaveLength(0);
  });

  test('calculates once per request key with limit 4', async () => {
    const recorder = journeyRecorder();
    const initialRequest = request();
    const { result, rerender } = await renderHook(
      ({ value }: { value: JourneyRequest }) => useJourneyPlan(value, recorder.port),
      { initialProps: { value: initialRequest } }
    );

    expect(recorder.calls).toHaveLength(1);
    expect(recorder.calls[0]!.input).toEqual({
      origin: initialRequest.origin,
      destination: initialRequest.destination,
      limit: 4,
    });

    await rerender({ value: { ...initialRequest } });
    expect(recorder.calls).toHaveLength(1);

    await act(() => recorder.calls[0]!.request.resolve(RESPONSE));
    expect(result.current).toEqual({
      status: 'ready',
      request: { ...initialRequest },
      response: RESPONSE,
    });
  });

  test('cancels changed and unmounted requests and protects state with the request key', async () => {
    const recorder = journeyRecorder();
    const first = request(0, 'republique');
    const second = request(0, 'nation');
    const retry = request(1, 'nation');
    const { result, rerender, unmount } = await renderHook(
      ({ value }: { value: JourneyRequest }) => useJourneyPlan(value, recorder.port),
      { initialProps: { value: first } }
    );

    await rerender({ value: second });
    expect(recorder.calls[0]!.signal.aborted).toBe(true);
    await act(() => recorder.calls[0]!.request.resolve(RESPONSE));
    expect(result.current).toEqual({ status: 'planning', request: second });

    await act(() => recorder.calls[1]!.request.reject(new Error('planning failed')));
    expect(result.current).toEqual({ status: 'error', request: second });

    await rerender({ value: retry });
    expect(recorder.calls).toHaveLength(3);
    expect(result.current).toEqual({ status: 'planning', request: retry });

    await unmount();
    expect(recorder.calls[2]!.signal.aborted).toBe(true);
  });
});

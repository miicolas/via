import type { DeparturesResponse } from '@via/contract';
import { act, renderHook } from '@testing-library/react-native';
import type { AppStateStatus } from 'react-native';

import {
  type DeparturesEnvironment,
  type DeparturesPort,
  useDepartures,
} from '@/features/departures/hooks/use-departures';

jest.mock('@/lib/api', () => ({ api: { departures: { forStation: jest.fn() } } }));

const RESPONSE: DeparturesResponse = {
  source: 'realtime',
  generatedAt: '2026-08-12T18:00:00+02:00',
  groups: [],
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

function departuresRecorder() {
  const calls: Array<{
    request: Deferred<DeparturesResponse>;
    signal: AbortSignal;
    stationId: string;
  }> = [];
  const port: DeparturesPort = {
    load: (stationId, signal) => {
      const request = deferred<DeparturesResponse>();
      calls.push({ request, signal, stationId });
      return request.promise;
    },
  };
  return { calls, port };
}

class ControlledDeparturesEnvironment implements DeparturesEnvironment {
  intervals: Array<{ active: boolean; callback: () => void; intervalMs: number }> = [];
  listener?: (state: AppStateStatus) => void;
  unsubscribed = false;

  scheduleEvery = (callback: () => void, intervalMs: number) => {
    const interval = { active: true, callback, intervalMs };
    this.intervals.push(interval);
    return () => {
      interval.active = false;
    };
  };

  subscribeAppState = (listener: (state: AppStateStatus) => void) => {
    this.listener = listener;
    return () => {
      this.unsubscribed = true;
      this.listener = undefined;
    };
  };

  emit(state: AppStateStatus) {
    this.listener?.(state);
  }

  tick() {
    for (const interval of this.intervals) {
      if (interval.active) interval.callback();
    }
  }
}

beforeEach(() => {
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => {
  jest.restoreAllMocks();
});

describe('useDepartures', () => {
  test('loads immediately and permits overlapping polls every 60 seconds', async () => {
    const recorder = departuresRecorder();
    const environment = new ControlledDeparturesEnvironment();
    const { result } = await renderHook(() =>
      useDepartures('IDFM:71264', recorder.port, environment)
    );

    expect(result.current.status).toBe('loading');
    expect(recorder.calls).toHaveLength(1);
    expect(environment.intervals[0]?.intervalMs).toBe(60_000);

    await act(() => {
      environment.tick();
      environment.tick();
    });
    expect(recorder.calls).toHaveLength(3);
  });

  test('suspends outside active and reloads immediately on return', async () => {
    const recorder = departuresRecorder();
    const environment = new ControlledDeparturesEnvironment();
    await renderHook(() => useDepartures('IDFM:71264', recorder.port, environment));

    await act(() => environment.emit('background'));
    await act(() => environment.tick());
    expect(recorder.calls).toHaveLength(1);

    await act(() => environment.emit('active'));
    expect(recorder.calls).toHaveLength(2);
    expect(environment.intervals.filter(({ active }) => active)).toHaveLength(1);

    await act(() => environment.emit('active'));
    expect(recorder.calls).toHaveLength(2);
  });

  test('cancels on station change and ignores the old station result', async () => {
    const recorder = departuresRecorder();
    const environment = new ControlledDeparturesEnvironment();
    const { result, rerender, unmount } = await renderHook(
      ({ stationId }: { stationId: string }) =>
        useDepartures(stationId, recorder.port, environment),
      { initialProps: { stationId: 'IDFM:71264' } }
    );

    await rerender({ stationId: 'IDFM:415852' });
    expect(recorder.calls[0]!.signal.aborted).toBe(true);
    expect(recorder.calls[1]!.stationId).toBe('IDFM:415852');

    await act(() => recorder.calls[0]!.request.resolve(RESPONSE));
    expect(result.current.status).toBe('loading');

    await act(() => recorder.calls[1]!.request.resolve(RESPONSE));
    expect(result.current).toEqual({ status: 'ready', response: RESPONSE });

    await unmount();
    expect(recorder.calls[1]!.signal.aborted).toBe(true);
    expect(environment.unsubscribed).toBe(true);
  });

  test('keeps an old result after a refresh failure', async () => {
    const recorder = departuresRecorder();
    const environment = new ControlledDeparturesEnvironment();
    const { result } = await renderHook(() =>
      useDepartures('IDFM:71264', recorder.port, environment)
    );

    await act(() => recorder.calls[0]!.request.resolve(RESPONSE));
    await act(() => environment.tick());
    await act(() => recorder.calls[1]!.request.reject(new Error('refresh failed')));

    expect(result.current).toEqual({ status: 'ready', response: RESPONSE });
  });

  test('surfaces an error when the station has no previous result', async () => {
    const recorder = departuresRecorder();
    const environment = new ControlledDeparturesEnvironment();
    const { result } = await renderHook(() =>
      useDepartures('IDFM:71264', recorder.port, environment)
    );

    await act(() => recorder.calls[0]!.request.reject(new Error('initial load failed')));

    expect(result.current).toEqual({ status: 'error' });
  });
});

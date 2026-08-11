import type { NetworkMap, NetworkRoute, NetworkStation } from '@via/contract';
import { describe, expect, test } from 'bun:test';

import {
  EMPTY_NETWORK_MESSAGE,
  isInterchange,
  networkState,
  resolveLine,
  routeBounds,
  sortRoutes,
} from './metro-network';

function route(shortName: string, id = `IDFM:${shortName}`): NetworkRoute {
  return {
    id,
    shortName,
    longName: `Ligne ${shortName}`,
    color: '#FFCD00',
    textColor: '#000000',
    segments: [
      {
        id: `shape-${shortName}`,
        coordinates: [
          { latitude: 48.86, longitude: 2.33 },
          { latitude: 48.85, longitude: 2.36 },
        ],
      },
    ],
  };
}

function station(
  name: string,
  positions: Record<string, { latitude: number; longitude: number }>
): NetworkStation {
  return { id: `stop-${name}`, name, routeIds: Object.keys(positions), positions };
}

const LINE_1 = route('1');
const LINE_4 = route('4');
const CHATELET = station('Châtelet', {
  'IDFM:1': { latitude: 48.8583, longitude: 2.347 },
  'IDFM:4': { latitude: 48.859, longitude: 2.3475 },
});
const LOUVRE = station('Louvre', { 'IDFM:1': { latitude: 48.8607, longitude: 2.341 } });
const NETWORK: NetworkMap = { routes: [LINE_4, LINE_1], stations: [CHATELET, LOUVRE] };

describe('sortRoutes', () => {
  test('orders numerically, with the suffix as tie-breaker', () => {
    const names = sortRoutes([route('10'), route('3bis'), route('2'), route('3'), route('1')]).map(
      (line) => line.shortName
    );

    expect(names).toEqual(['1', '2', '3', '3bis', '10']);
  });

  test('pushes a non-numeric name to the end rather than throwing', () => {
    const names = sortRoutes([route('B'), route('7')]).map((line) => line.shortName);

    expect(names).toEqual(['7', 'B']);
  });
});

describe('routeBounds', () => {
  test('returns the south-west and north-east corners', () => {
    expect(routeBounds(LINE_1)).toEqual([
      { latitude: 48.85, longitude: 2.33 },
      { latitude: 48.86, longitude: 2.36 },
    ]);
  });

  test('returns nothing for a line with no drawn track', () => {
    expect(routeBounds({ ...LINE_1, segments: [] })).toEqual([]);
  });
});

describe('resolveLine', () => {
  const lines = sortRoutes(NETWORK.routes);

  test('keeps only the stations that sit on the line, with their position on it', () => {
    const view = resolveLine(lines, NETWORK.stations, 'IDFM:4')!;

    expect(view.route.shortName).toBe('4');
    expect(view.stations.map((s) => s.name)).toEqual(['Châtelet']);
    expect(view.stations[0]!.coordinate).toEqual({ latitude: 48.859, longitude: 2.3475 });
  });

  test('gives a station its own coordinate per line', () => {
    const onOne = resolveLine(lines, NETWORK.stations, 'IDFM:1')!;
    const onFour = resolveLine(lines, NETWORK.stations, 'IDFM:4')!;

    expect(onOne.stations[0]!.coordinate).not.toEqual(onFour.stations[0]!.coordinate);
  });

  test('counts interchanges among the line’s own stations', () => {
    expect(resolveLine(lines, NETWORK.stations, 'IDFM:1')!.interchangeCount).toBe(1);
    expect(resolveLine(lines, NETWORK.stations, 'IDFM:4')!.interchangeCount).toBe(1);
  });

  test('falls back to the first line, which sorting makes line 1', () => {
    expect(resolveLine(lines, NETWORK.stations, undefined)!.route.shortName).toBe('1');
    expect(resolveLine(lines, NETWORK.stations, 'IDFM:nope')!.route.shortName).toBe('1');
  });

  test('resolves nothing when there is no line at all', () => {
    expect(resolveLine([], NETWORK.stations, undefined)).toBeUndefined();
  });
});

describe('isInterchange', () => {
  test('is true only when a station serves more than one line', () => {
    expect(isInterchange(CHATELET)).toBe(true);
    expect(isInterchange(LOUVRE)).toBe(false);
  });
});

describe('networkState', () => {
  test('is loading while nothing has arrived and nothing failed', () => {
    expect(networkState(undefined, undefined, undefined)).toEqual({ status: 'loading' });
  });

  test('is an error when the load failed', () => {
    expect(networkState(undefined, 'boom', undefined)).toEqual({ status: 'error', message: 'boom' });
  });

  test('is ready with a line already resolved', () => {
    const state = networkState(NETWORK, undefined, 'IDFM:4');

    expect(state.status).toBe('ready');
    if (state.status !== 'ready') return;
    expect(state.line.route.shortName).toBe('4');
    expect(state.lines.map((line) => line.shortName)).toEqual(['1', '4']);
  });

  /**
   * The state the old shape could not express: an empty network reported itself
   * ready with no selected line, and every component below carried a `| undefined`
   * branch to cope.
   */
  test('treats a network with no line as an error, not an empty success', () => {
    expect(networkState({ routes: [], stations: [] }, undefined, undefined)).toEqual({
      status: 'error',
      message: EMPTY_NETWORK_MESSAGE,
    });
  });

  test('prefers data over a stale error once the retry succeeds', () => {
    expect(networkState(NETWORK, 'boom', undefined).status).toBe('ready');
  });
});

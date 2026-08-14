import type { NetworkRoute, NetworkStation, RailMap } from '@via/contract';
import { describe, expect, test } from 'bun:test';

import { isInterchange, resolveLine, routeBounds, sortRoutes } from './metro-network';

function route(
  shortName: string,
  id = `IDFM:${shortName}`,
  mode: NetworkRoute['mode'] = 'metro'
): NetworkRoute {
  return {
    id,
    shortName,
    color: '#FFCD00',
    textColor: '#000000',
    mode,
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
  coordinate: { latitude: number; longitude: number },
  routeIds: string[]
): NetworkStation {
  return { id: `stop-${name}`, name, coordinate, routeIds };
}

const LINE_1 = route('1');
const LINE_4 = route('4');
const CHATELET = station('Châtelet', { latitude: 48.8583, longitude: 2.347 }, [
  'IDFM:1',
  'IDFM:4',
]);
const LOUVRE = station('Louvre', { latitude: 48.8607, longitude: 2.341 }, ['IDFM:1']);
const NETWORK: RailMap = { routes: [LINE_4, LINE_1], stations: [CHATELET, LOUVRE] };

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

  test('keeps metro first, then RER, then bus even when their names collide', () => {
    const ordered = sortRoutes([
      route('1', 'bus-1', 'bus'),
      route('B', 'rer-b', 'rer'),
      route('1', 'metro-1'),
    ]).map((line) => `${line.mode}:${line.shortName}`);

    expect(ordered).toEqual(['metro:1', 'rer:B', 'bus:1']);
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

  test('keeps only the stations that sit on the line', () => {
    const view = resolveLine(lines, NETWORK.stations, 'IDFM:4')!;

    expect(view.route.shortName).toBe('4');
    expect(view.stations.map((s) => s.name)).toEqual(['Châtelet']);
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

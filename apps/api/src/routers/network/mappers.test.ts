import { describe, expect, test } from 'bun:test';
import { networkMapSchema } from '@via/contract';

import { toNetworkMap } from './mappers';
import type { MetroPatternRow, MetroStationPositionRow } from './queries';

const LINE_1 = '{"type":"LineString","coordinates":[[2.3364,48.8606],[2.3522,48.8566]]}';
const LINE_1_BRANCH = '{"type":"LineString","coordinates":[[2.3522,48.8566],[2.3600,48.8600]]}';
const LINE_4 = '{"type":"LineString","coordinates":[[2.3470,48.8583],[2.3480,48.8500]]}';

const patternRows: MetroPatternRow[] = [
  {
    routeId: 'IDFM:C01371',
    shortName: '1',
    longName: 'La Défense - Château de Vincennes',
    color: 'FFCD00',
    textColor: '000000',
    patternId: 'shape-1-a',
    geometry: LINE_1,
  },
  {
    routeId: 'IDFM:C01371',
    shortName: '1',
    longName: 'La Défense - Château de Vincennes',
    color: 'FFCD00',
    textColor: '000000',
    patternId: 'shape-1-b',
    geometry: LINE_1_BRANCH,
  },
  {
    routeId: 'IDFM:C01374',
    shortName: '4',
    longName: 'Porte de Clignancourt - Bagneux',
    color: 'A0006E',
    textColor: 'FFFFFF',
    patternId: 'shape-4-a',
    geometry: LINE_4,
  },
];

/**
 * Châtelet is the interchange: it appears once per line it serves, snapped to a
 * different point each time. Louvre is served by line 1 only.
 */
const stationRows: MetroStationPositionRow[] = [
  {
    id: 'IDFM:474151',
    name: 'Châtelet',
    routeId: 'IDFM:C01371',
    longitude: 2.3470,
    latitude: 48.8583,
  },
  {
    id: 'IDFM:474151',
    name: 'Châtelet',
    routeId: 'IDFM:C01374',
    longitude: 2.3475,
    latitude: 48.8590,
  },
  {
    id: 'IDFM:463127',
    name: 'Louvre - Rivoli',
    routeId: 'IDFM:C01371',
    longitude: 2.3410,
    latitude: 48.8607,
  },
];

describe('toNetworkMap', () => {
  test('collapses a route’s patterns into its segments', () => {
    const { routes } = toNetworkMap(patternRows, stationRows);

    expect(routes).toHaveLength(2);

    const [lineOne] = routes;
    expect(lineOne.id).toBe('IDFM:C01371');
    expect(lineOne.shortName).toBe('1');
    expect(lineOne.segments.map((segment) => segment.id)).toEqual(['shape-1-a', 'shape-1-b']);
    expect(lineOne.segments[0].coordinates).toEqual([
      { latitude: 48.8606, longitude: 2.3364 },
      { latitude: 48.8566, longitude: 2.3522 },
    ]);
  });

  test('makes GTFS colours CSS-ready', () => {
    const { routes } = toNetworkMap(patternRows, stationRows);

    expect(routes[0].color).toBe('#FFCD00');
    expect(routes[0].textColor).toBe('#000000');
    expect(routes[1].color).toBe('#A0006E');
  });

  test('gives an interchange one entry per line, with a position for each', () => {
    const { stations } = toNetworkMap(patternRows, stationRows);

    expect(stations).toHaveLength(2);

    const [chatelet] = stations;
    expect(chatelet.name).toBe('Châtelet');
    expect(Object.keys(chatelet.positions)).toEqual(['IDFM:C01371', 'IDFM:C01374']);
    expect(chatelet.positions['IDFM:C01371']).toEqual({ latitude: 48.8583, longitude: 2.347 });
    expect(chatelet.positions['IDFM:C01374']).toEqual({ latitude: 48.859, longitude: 2.3475 });
  });

  test('keys positions by route id so a single dot can move between lines', () => {
    const { stations } = toNetworkMap(patternRows, stationRows);
    const louvre = stations.find((station) => station.name === 'Louvre - Rivoli');

    expect(Object.keys(louvre!.positions)).toEqual(['IDFM:C01371']);
  });

  /**
   * PostGIS aggregates come back as strings on some driver paths while the row
   * type says `number`. The mapper's `Number()` calls are what keep the wire
   * contract honest, so the cast here reproduces the driver, not a type error.
   */
  test('coerces string aggregates into numbers', () => {
    const stringy = [
      {
        id: 'IDFM:474151',
        name: 'Châtelet',
        routeId: 'IDFM:C01371',
        longitude: '2.3470',
        latitude: '48.8583',
      },
    ] as unknown as MetroStationPositionRow[];

    const { stations } = toNetworkMap(patternRows, stringy);

    expect(stations[0].positions['IDFM:C01371']).toEqual({
      latitude: 48.8583,
      longitude: 2.347,
    });
  });

  /**
   * The real contract, not a copy of it. Asserting against a hand-written
   * duplicate would let the two drift and still pass, which is the failure this
   * test exists to prevent.
   */
  test('matches the wire contract', () => {
    expect(() => networkMapSchema.parse(toNetworkMap(patternRows, stationRows))).not.toThrow();
  });

  /** The `#` prefix is the mapper's job — GTFS stores colours bare. */
  test('emits CSS colours the contract alone would not catch', () => {
    const { routes } = toNetworkMap(patternRows, stationRows);

    for (const route of routes) {
      expect(route.color).toMatch(/^#[0-9A-Fa-f]{6}$/);
      expect(route.textColor).toMatch(/^#[0-9A-Fa-f]{6}$/);
    }
  });

  test('returns empty collections rather than throwing on an empty network', () => {
    expect(toNetworkMap([], [])).toEqual({ routes: [], stations: [] });
  });
});

import { describe, expect, test } from 'bun:test';
import { railMapSchema } from '@via/contract';

import type { NetworkPatternRow, RailStationPositionRow } from './queries';
import { toRailMap } from './to-rail-map';

const LINE_1 = '{"type":"MultiLineString","coordinates":[[[2.3364,48.8606],[2.3522,48.8566]]]}';
const LINE_1_BRANCH =
  '{"type":"MultiLineString","coordinates":[[[2.3522,48.8566],[2.3600,48.8600]]]}';
const LINE_4 = '{"type":"MultiLineString","coordinates":[[[2.3470,48.8583],[2.3480,48.8500]]]}';

const patternRows: NetworkPatternRow[] = [
  {
    routeId: 'IDFM:C01371',
    shortName: '1',
    color: 'FFCD00',
    textColor: '000000',
    routeType: 1,
    patternId: 'shape-1-a',
    geometry: LINE_1,
  },
  {
    routeId: 'IDFM:C01371',
    shortName: '1',
    color: 'FFCD00',
    textColor: '000000',
    routeType: 1,
    patternId: 'shape-1-b',
    geometry: LINE_1_BRANCH,
  },
  {
    routeId: 'IDFM:C01374',
    shortName: '4',
    color: 'A0006E',
    textColor: 'FFFFFF',
    routeType: 1,
    patternId: 'shape-4-a',
    geometry: LINE_4,
  },
];

/**
 * Châtelet is the interchange: it appears once per line it serves, snapped to a
 * different point each time. Louvre is served by line 1 only.
 */
const stationRows: RailStationPositionRow[] = [
  {
    id: 'IDFM:474151',
    name: 'Châtelet',
    routeId: 'IDFM:C01371',
    longitude: 2.3470,
    latitude: 48.8583,
    accessibilityCondition: 'staffAssistance',
    accessibilityDetail: 'Agent présent aux heures d’ouverture',
    toiletStopId: 'IDFM:474151',
    toiletDetail: 'Accès gratuit · Accessible PMR\nPrès de la sortie 3.',
    fountainStopId: 'IDFM:474151',
    fountainCondition: 'available',
    fountainDetail: 'Accessible PMR · Remplissage de gourde possible',
  },
  {
    id: 'IDFM:474151',
    name: 'Châtelet',
    routeId: 'IDFM:C01374',
    longitude: 2.3475,
    latitude: 48.8590,
    accessibilityCondition: 'staffAssistance',
    accessibilityDetail: 'Agent présent aux heures d’ouverture',
    toiletStopId: 'IDFM:474151',
    toiletDetail: 'Accès gratuit · Accessible PMR\nPrès de la sortie 3.',
    fountainStopId: 'IDFM:474151',
    fountainCondition: 'available',
    fountainDetail: 'Accessible PMR · Remplissage de gourde possible',
  },
  {
    id: 'IDFM:463127',
    name: 'Louvre - Rivoli',
    routeId: 'IDFM:C01371',
    longitude: 2.3410,
    latitude: 48.8607,
    accessibilityCondition: null,
    accessibilityDetail: null,
    toiletStopId: null,
    toiletDetail: null,
    fountainStopId: null,
    fountainCondition: null,
    fountainDetail: null,
  },
];

describe('toRailMap', () => {
  test('collapses a route’s patterns into its segments', () => {
    const { routes } = toRailMap(patternRows, stationRows);

    expect(routes).toHaveLength(2);

    const [lineOne] = routes;
    expect(lineOne.id).toBe('IDFM:C01371');
    expect(lineOne.shortName).toBe('1');
    expect(lineOne.mode).toBe('metro');
    expect(lineOne.segments.map((segment) => segment.id)).toEqual(['shape-1-a#0', 'shape-1-b#0']);
    expect(lineOne.segments[0].coordinates).toEqual([
      { latitude: 48.8606, longitude: 2.3364 },
      { latitude: 48.8566, longitude: 2.3522 },
    ]);
  });

  /**
   * The stored geometry is empty when an opposite direction adds no branch: no
   * stroke to draw twice, but its route keeps its other patterns' segments.
   */
  test('keeps a route whose extra pattern fully deduplicated', () => {
    const returnPattern: NetworkPatternRow = {
      ...patternRows[0],
      patternId: 'shape-1-return',
      geometry: '{"type":"MultiLineString","coordinates":[]}',
    };

    const { routes } = toRailMap([...patternRows, returnPattern], stationRows);
    const [lineOne] = routes;

    expect(lineOne.segments.map((segment) => segment.id)).toEqual(['shape-1-a#0', 'shape-1-b#0']);
  });

  /** A loop or branch survives the subtraction as two runs either side of the trunk. */
  test('splits a cut pattern into one segment per remaining run of track', () => {
    const cutPattern: NetworkPatternRow = {
      ...patternRows[0],
      patternId: 'shape-1-loop',
      geometry:
        '{"type":"MultiLineString","coordinates":[[[2.3364,48.8606],[2.3522,48.8566]],[[2.3600,48.8600],[2.3700,48.8650]]]}',
    };

    const { routes } = toRailMap([cutPattern], stationRows);

    expect(routes[0].segments.map((segment) => segment.id)).toEqual([
      'shape-1-loop#0',
      'shape-1-loop#1',
    ]);
  });

  /** ~20 m of leftover track is subtraction confetti, not a branch. */
  test('discards slivers left over by the subtraction', () => {
    const withSliver: NetworkPatternRow = {
      ...patternRows[0],
      patternId: 'shape-1-sliver',
      geometry:
        '{"type":"MultiLineString","coordinates":[[[2.3364,48.8606],[2.3522,48.8566]],[[2.3600,48.8600],[2.36027,48.8600]]]}',
    };

    const { routes } = toRailMap([withSliver], stationRows);

    expect(routes[0].segments.map((segment) => segment.id)).toEqual(['shape-1-sliver#0']);
  });

  test('makes GTFS colours CSS-ready', () => {
    const { routes } = toRailMap(patternRows, stationRows);

    expect(routes[0].color).toBe('#FFCD00');
    expect(routes[0].textColor).toBe('#000000');
    expect(routes[1].color).toBe('#A0006E');
  });

  test('anchors a station on its first serving line and lists every line', () => {
    const { stations } = toRailMap(patternRows, stationRows);

    expect(stations).toHaveLength(2);

    const [chatelet] = stations;
    expect(chatelet.name).toBe('Châtelet');
    expect(chatelet.routeIds).toEqual(['IDFM:C01371', 'IDFM:C01374']);
    expect(chatelet.accessibility).toEqual({
      condition: 'staffAssistance',
      label: 'Avec un agent',
      comment: 'Agent présent aux heures d’ouverture',
    });
    expect(chatelet.toilets).toEqual({
      label: 'Sanitaires disponibles',
      detail: 'Accès gratuit · Accessible PMR\nPrès de la sortie 3.',
    });
    expect(chatelet.fountains).toEqual({
      status: 'available',
      label: 'Fontaine d’eau potable à proximité',
      detail: 'Accessible PMR · Remplissage de gourde possible',
    });
    // The line-1 row leads, so the anchor is the projection onto line 1 — the
    // same point the old payload served as the station's primary position.
    expect(chatelet.coordinate).toEqual({
      latitude: 48.85796592134573,
      longitude: 2.3468046106843596,
    });
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
    ] as unknown as RailStationPositionRow[];

    const { stations } = toRailMap(patternRows, stringy);

    expect(typeof stations[0].coordinate.latitude).toBe('number');
    expect(typeof stations[0].coordinate.longitude).toBe('number');
  });

  /**
   * The real contract, not a copy of it. Asserting against a hand-written
   * duplicate would let the two drift and still pass, which is the failure this
   * test exists to prevent.
   */
  test('matches the wire contract', () => {
    expect(() => railMapSchema.parse(toRailMap(patternRows, stationRows))).not.toThrow();
  });

  /** The `#` prefix is the mapper's job — GTFS stores colours bare. */
  test('emits CSS colours the contract alone would not catch', () => {
    const { routes } = toRailMap(patternRows, stationRows);

    for (const route of routes) {
      expect(route.color).toMatch(/^#[0-9A-Fa-f]{6}$/);
      expect(route.textColor).toMatch(/^#[0-9A-Fa-f]{6}$/);
    }
  });

  test('returns empty collections rather than throwing on an empty network', () => {
    expect(toRailMap([], [])).toEqual({ routes: [], stations: [] });
  });
});

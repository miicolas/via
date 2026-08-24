import { describe, expect, test } from 'bun:test';

import { mapBoardingPositions, mapExits, stationRouteKey, zoneOf } from './map-wayfinding';
import { inferQuayDirection } from './quay-directions';

/** Real rows, trimmed: Châtelet metro (ZdA 42587 → ZdC 71264) and its line 7 quays. */
const STOP_AREA_PARENTS = new Map([['42587', '71264'], ['45102', '474151']]);

const ACCESSES = [
  {
    accid: '50147797',
    accname: 'pl. du Châtelet',
    accshortname: 16,
    accdescription: null,
    accisexit: 'true',
    accgeopoint: { lon: 2.3472936097922545, lat: 48.85765022656312 },
  },
  {
    accid: '50147794',
    accname: 'r. des Lavandières',
    accshortname: 13,
    accdescription: null,
    accisexit: 'true',
    accgeopoint: { lon: 2.3461186959929123, lat: 48.858956863779206 },
  },
];

const ACCESS_RELATIONS = [
  { zdaid: '42587', accid: '50147797' },
  { zdaid: '42587', accid: '50147794' },
];

const KNOWN_STOP_IDS = new Set(['IDFM:71264']);
const KNOWN_QUAY_IDS = new Set(['IDFM:463060', 'IDFM:22364', 'IDFM:22087']);

function positionRow(overrides: Record<string, unknown> = {}) {
  return {
    from_type: 'stop_point',
    from_id: 463060,
    line_id: 'C01377',
    to_type: 'access_point',
    to_id: 50147797,
    position: 5,
    position_max: 5,
    position_average: 'Arrière',
    equipment_type: null,
    ...overrides,
  };
}

describe('mapExits', () => {
  test('walks an access up to the Via station it belongs to', () => {
    const exits = mapExits({
      accesses: ACCESSES,
      accessRelations: ACCESS_RELATIONS,
      stopAreaParents: STOP_AREA_PARENTS,
      knownStopIDs: KNOWN_STOP_IDS,
    });

    expect(exits.get('IDFM:50147797')).toMatchObject({
      id: 'IDFM:50147797',
      stopId: 'IDFM:71264',
      name: 'pl. du Châtelet',
      number: 16,
      sourceRef: '50147797',
    });
    expect(exits.size).toBe(2);
  });

  test('drops entrance-only accesses and accesses to stations we never imported', () => {
    const exits = mapExits({
      accesses: [
        ...ACCESSES,
        { ...ACCESSES[0], accid: '1', accisexit: 'false' },
        { ...ACCESSES[0], accid: '2' },
      ],
      // Access 2 hangs off a stop area whose station is not in the network.
      accessRelations: [...ACCESS_RELATIONS, { zdaid: '42587', accid: '1' }, { zdaid: '45102', accid: '2' }],
      stopAreaParents: STOP_AREA_PARENTS,
      knownStopIDs: KNOWN_STOP_IDS,
    });

    expect([...exits.keys()].sort()).toEqual(['IDFM:50147794', 'IDFM:50147797']);
  });
});

describe('mapBoardingPositions', () => {
  const exitIDs = new Set(['IDFM:50147797']);

  test('keeps the two quays of a station apart', () => {
    const positions = mapBoardingPositions({
      trainPositions: [
        positionRow(),
        positionRow({ from_id: 22364, position: 1, position_average: 'Avant' }),
      ],
      exitIDs,
      knownQuayIDs: KNOWN_QUAY_IDS,
    });

    // Same exit, opposite directions: the advice is mirrored, never merged.
    expect(positions).toEqual([
      expect.objectContaining({ fromQuayId: 'IDFM:463060', car: 5, zone: 'rear' }),
      expect.objectContaining({ fromQuayId: 'IDFM:22364', car: 1, zone: 'front' }),
    ]);
    expect(positions.every((row) => row.routeId === 'IDFM:C01377')).toBe(true);
  });

  test('reads a connection target as a quay and translates the equipment', () => {
    const [position] = mapBoardingPositions({
      trainPositions: [
        positionRow({ to_type: 'stop_point', to_id: 22087, equipment_type: 'Ascenseur' }),
      ],
      exitIDs,
      knownQuayIDs: KNOWN_QUAY_IDS,
    });

    expect(position).toMatchObject({
      targetId: 'IDFM:22087',
      targetKind: 'transfer',
      equipment: 'lift',
    });
  });

  test('drops rows whose ends are not in the network', () => {
    const positions = mapBoardingPositions({
      trainPositions: [
        positionRow({ from_id: 999999 }),
        positionRow({ to_id: 999999 }),
        positionRow({ to_type: 'stop_point', to_id: 999999 }),
        positionRow({ position: 9 }),
      ],
      exitIDs,
      knownQuayIDs: KNOWN_QUAY_IDS,
    });

    expect(positions).toEqual([]);
  });

  test('falls back to a direction-safe station advice when Navitia aggregates RER quays', () => {
    const positions = mapBoardingPositions({
      trainPositions: [
        positionRow({
          from_id: 473964,
          from_name: 'Chatou - Croissy',
          line_id: 'C01742',
          line_name: 'A',
          to_id: 50148532,
          position: 4,
          position_max: 10,
          position_average: 'Avant',
        }),
        positionRow({
          from_id: 473965,
          from_name: 'Chatou - Croissy',
          line_id: 'C01742',
          line_name: 'A',
          to_id: 50148532,
          position: 4,
          position_max: 10,
          position_average: 'Avant',
        }),
        // This exit is only documented from one of the two directional quays,
        // so collapsing it to the station would risk advising the wrong car.
        positionRow({
          from_id: 473965,
          from_name: 'Chatou - Croissy',
          line_id: 'C01742',
          line_name: 'A',
          to_id: 50148533,
          position: 1,
          position_max: 10,
          position_average: 'Avant',
        }),
      ],
      exitIDs: new Set(['IDFM:50148532', 'IDFM:50148533']),
      // Navitia currently returns this aggregate stop point for RER A journeys.
      knownQuayIDs: new Set(['IDFM:monomodalStopPlace:53783']),
      stopAreaByQuay: new Map([
        ['473964', '53783'],
        ['473965', '53783'],
      ]),
    });

    expect(positions).toEqual([
      expect.objectContaining({
        fromQuayId: 'IDFM:monomodalStopPlace:53783',
        targetId: 'IDFM:50148532',
        routeId: 'IDFM:C01742',
        car: 4,
        carCount: 10,
        zone: 'front',
      }),
    ]);
  });
});

/** An east–west platform: direction 0 trains travel east, their head to the east. */
const CHATOU = { lon: 2.1559, lat: 48.8852 };
const EXIT_EAST = { lon: 2.158, lat: 48.8852 };
const EXIT_WEST = { lon: 2.1538, lat: 48.8852 };
const TRAVEL_VECTORS = [
  { directionId: 0, east: 1, north: 0 },
  { directionId: 1, east: -1, north: 0 },
];

describe('inferQuayDirection', () => {
  test('a front carriage towards an eastern exit means the train heads east', () => {
    const directionId = inferQuayDirection({
      stationLocation: CHATOU,
      travelVectors: TRAVEL_VECTORS,
      advice: [{ car: 2, carCount: 10, exitLocation: EXIT_EAST }],
    });

    expect(directionId).toBe(0);
  });

  test('a rear carriage towards the same exit means the opposite direction', () => {
    const directionId = inferQuayDirection({
      stationLocation: CHATOU,
      travelVectors: TRAVEL_VECTORS,
      advice: [{ car: 9, carCount: 10, exitLocation: EXIT_EAST }],
    });

    expect(directionId).toBe(1);
  });

  test('contradictory rows leave the quay unresolved', () => {
    const directionId = inferQuayDirection({
      stationLocation: CHATOU,
      travelVectors: TRAVEL_VECTORS,
      advice: [
        { car: 2, carCount: 10, exitLocation: EXIT_EAST },
        { car: 2, carCount: 10, exitLocation: EXIT_WEST },
      ],
    });

    expect(directionId).toBeUndefined();
  });

  test('middle carriages and central exits abstain', () => {
    const directionId = inferQuayDirection({
      stationLocation: CHATOU,
      travelVectors: TRAVEL_VECTORS,
      advice: [
        { car: 5, carCount: 10, exitLocation: EXIT_EAST },
        { car: 1, carCount: 10, exitLocation: { lon: 2.15592, lat: 48.8852 } },
      ],
    });

    expect(directionId).toBeUndefined();
  });
});

describe('mapBoardingPositions with referential-only quays', () => {
  const directionOptions = {
    exitIDs: new Set(['IDFM:50148532', 'IDFM:50148533']),
    knownQuayIDs: new Set(['IDFM:monomodalStopPlace:53783']),
    stopAreaByQuay: new Map([['473964', '53783'], ['473965', '53783']]),
    stationByStopArea: new Map([['53783', 'IDFM:64483']]),
    exitLocationById: new Map([
      ['IDFM:50148532', EXIT_EAST],
      ['IDFM:50148533', EXIT_WEST],
    ]),
    stationLocationByStopId: new Map([['IDFM:64483', CHATOU]]),
    travelVectorsByStationRoute: new Map([
      [stationRouteKey('IDFM:64483', 'IDFM:C01742'), TRAVEL_VECTORS],
    ]),
  };

  function rerRow(overrides: Record<string, unknown> = {}) {
    return positionRow({
      from_id: 473964,
      line_id: 'C01742',
      to_id: 50148532,
      position: 2,
      position_max: 10,
      position_average: 'Avant',
      ...overrides,
    });
  }

  test('stamps a resolvable RER quay with its station and direction', () => {
    const positions = mapBoardingPositions({
      ...directionOptions,
      trainPositions: [
        rerRow(),
        rerRow({ from_id: 473965, position: 9, position_average: 'Arrière' }),
      ],
    });

    expect(positions).toEqual([
      expect.objectContaining({
        fromQuayId: 'IDFM:473964',
        stationStopId: 'IDFM:64483',
        directionId: 0,
        car: 2,
      }),
      expect.objectContaining({
        fromQuayId: 'IDFM:473965',
        stationStopId: 'IDFM:64483',
        directionId: 1,
        car: 9,
      }),
    ]);
  });

  test('an unresolved quay contributes nothing beyond the direction-safe aggregate', () => {
    const positions = mapBoardingPositions({
      ...directionOptions,
      // Both quays advise the same middle carriage: no direction signal, but
      // a safe station-level aggregate.
      trainPositions: [
        rerRow({ position: 5, position_average: 'Milieu' }),
        rerRow({ from_id: 473965, position: 5, position_average: 'Milieu' }),
      ],
    });

    expect(positions).toEqual([
      expect.objectContaining({
        fromQuayId: 'IDFM:monomodalStopPlace:53783',
        stationStopId: 'IDFM:64483',
        directionId: null,
        car: 5,
      }),
    ]);
  });

  test('renames an RER transfer target to the monomodal stop the planner reports', () => {
    const positions = mapBoardingPositions({
      exitIDs: new Set(),
      knownQuayIDs: new Set(['IDFM:463060', 'IDFM:monomodalStopPlace:53783']),
      stopAreaByQuay: new Map([['473970', '53783']]),
      trainPositions: [
        positionRow({ to_type: 'stop_point', to_id: 473970 }),
      ],
    });

    expect(positions).toEqual([
      expect.objectContaining({
        fromQuayId: 'IDFM:463060',
        targetId: 'IDFM:monomodalStopPlace:53783',
        targetKind: 'transfer',
      }),
    ]);
  });

  test('drops a renamed transfer when the two merged platforms disagree', () => {
    const positions = mapBoardingPositions({
      exitIDs: new Set(),
      knownQuayIDs: new Set(['IDFM:463060', 'IDFM:monomodalStopPlace:53783']),
      stopAreaByQuay: new Map([['473970', '53783'], ['473971', '53783']]),
      trainPositions: [
        positionRow({ to_type: 'stop_point', to_id: 473970 }),
        positionRow({ to_type: 'stop_point', to_id: 473971, position: 1, position_average: 'Avant' }),
      ],
    });

    expect(positions).toEqual([]);
  });
});

describe('zoneOf', () => {
  test('falls back to thirds of the train when the source label is junk', () => {
    // The published dataset carries one row with `position_average: '7'`.
    expect(zoneOf('7', 5, 5)).toBe('rear');
    expect(zoneOf('7', 1, 5)).toBe('front');
    expect(zoneOf('7', 3, 5)).toBe('middle');
    expect(zoneOf(undefined, 4, 8)).toBe('middle');
  });

  test('trusts the source label when it is one Via knows', () => {
    expect(zoneOf('Milieu', 1, 8)).toBe('middle');
  });
});

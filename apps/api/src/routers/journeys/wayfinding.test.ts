import type { Coordinate, Journey, JourneySection } from '@via/contract';
import { describe, expect, test } from 'bun:test';

import { applyWayfinding, type WayfindingSnapshot } from './wayfinding';

/**
 * Châtelet as the referential describes it: station `IDFM:71264`, two line-7
 * quays facing opposite directions, and two exits several hundred metres apart.
 */
const CHATELET = { latitude: 48.8570, longitude: 2.3481 };
const PLACE_DU_CHATELET = { latitude: 48.85765, longitude: 2.34729 };
const RUE_DES_LAVANDIERES = { latitude: 48.85896, longitude: 2.34612 };

const SNAPSHOT: WayfindingSnapshot = {
  stationByStopId: new Map([
    ['stop_point:IDFM:463060', 'IDFM:71264'],
    ['stop_point:IDFM:22364', 'IDFM:71264'],
    ['stop_point:IDFM:22087', 'IDFM:71264'],
    ['IDFM:71264', 'IDFM:71264'],
  ]),
  exitsByStopId: new Map([[
    'IDFM:71264',
    [
      { id: 'IDFM:50147797', stopId: 'IDFM:71264', name: 'pl. du Châtelet', number: 16, coordinate: PLACE_DU_CHATELET },
      { id: 'IDFM:50147794', stopId: 'IDFM:71264', name: 'r. des Lavandières', number: 13, coordinate: RUE_DES_LAVANDIERES },
    ],
  ]]),
  positionsByQuayId: new Map([
    ['IDFM:463060', [
      { fromQuayId: 'IDFM:463060', targetId: 'IDFM:50147797', targetKind: 'exit', car: 5, carCount: 5, zone: 'rear', equipment: null },
      { fromQuayId: 'IDFM:463060', targetId: 'IDFM:50147794', targetKind: 'exit', car: 4, carCount: 5, zone: 'rear', equipment: 'lift' },
      { fromQuayId: 'IDFM:463060', targetId: 'IDFM:22087', targetKind: 'transfer', car: 5, carCount: 5, zone: 'rear', equipment: null },
    ]],
    ['IDFM:22364', [
      { fromQuayId: 'IDFM:22364', targetId: 'IDFM:50147797', targetKind: 'exit', car: 1, carCount: 5, zone: 'front', equipment: null },
    ]],
  ]),
};

function transit(stopIDs: string[], overrides: Partial<JourneySection> = {}): JourneySection {
  return {
    type: 'transit',
    durationSeconds: 600,
    from: { name: 'Départ', coordinate: CHATELET },
    to: { name: 'Arrivée', coordinate: CHATELET },
    geometry: [],
    stops: stopIDs.map((id) => ({ id, name: id, coordinate: CHATELET })),
    ...overrides,
  };
}

function walk(): JourneySection {
  return {
    type: 'walk',
    durationSeconds: 240,
    from: { name: 'Arrivée', coordinate: CHATELET },
    to: { name: 'Destination', coordinate: PLACE_DU_CHATELET },
    geometry: [],
    stops: [],
  };
}

function journey(sections: JourneySection[]): Journey {
  return {
    id: 'journey',
    qualifier: 'recommended',
    durationSeconds: 1_200,
    walkingDurationSeconds: 240,
    transferCount: 0,
    departureAt: '2026-08-21T08:00:00+02:00',
    arrivalAt: '2026-08-21T08:20:00+02:00',
    status: 'normal',
    warnings: [],
    sections,
  };
}

function apply(sections: JourneySection[], destination: Coordinate) {
  return applyWayfinding(journey(sections), destination, SNAPSHOT).sections;
}

describe('applyWayfinding', () => {
  test('picks the exit nearest the destination and the carriage that serves it', () => {
    const sections = apply(
      [transit(['stop_point:IDFM:21958', 'stop_point:IDFM:463060']), walk()],
      PLACE_DU_CHATELET
    );

    expect(sections[0]!.exit).toMatchObject({
      id: 'IDFM:50147797',
      name: 'pl. du Châtelet',
      number: 16,
    });
    expect(sections[0]!.exit!.walkingMeters).toBeLessThan(20);
    expect(sections[0]!.boardingPosition).toEqual({
      car: 5,
      carCount: 5,
      zone: 'rear',
      reason: 'exit',
    });
  });

  test('another destination picks another exit, and with it another carriage', () => {
    const sections = apply(
      [transit(['stop_point:IDFM:21958', 'stop_point:IDFM:463060']), walk()],
      RUE_DES_LAVANDIERES
    );

    expect(sections[0]!.exit).toMatchObject({ id: 'IDFM:50147794', number: 13 });
    expect(sections[0]!.boardingPosition).toMatchObject({ car: 4, equipment: 'lift' });
  });

  test('the opposite quay mirrors the advice for the very same exit', () => {
    const sections = apply(
      [transit(['stop_point:IDFM:21958', 'stop_point:IDFM:22364']), walk()],
      PLACE_DU_CHATELET
    );

    expect(sections[0]!.exit!.id).toBe('IDFM:50147797');
    expect(sections[0]!.boardingPosition).toMatchObject({ car: 1, zone: 'front' });
  });

  test('keeps the nearest exit when that exit has no carriage advice', () => {
    const snapshotWithoutNearestPosition: WayfindingSnapshot = {
      ...SNAPSHOT,
      positionsByQuayId: new Map([[
        'IDFM:463060',
        [{
          fromQuayId: 'IDFM:463060',
          targetId: 'IDFM:50147794',
          targetKind: 'exit',
          car: 4,
          carCount: 5,
          zone: 'rear',
          equipment: null,
        }],
      ]]),
    };
    const result = applyWayfinding(
      journey([transit(['stop_point:IDFM:21958', 'stop_point:IDFM:463060']), walk()]),
      PLACE_DU_CHATELET,
      snapshotWithoutNearestPosition,
    );

    expect(result.sections[0]!.exit?.id).toBe('IDFM:50147797');
    expect(result.sections[0]!.boardingPosition).toBeUndefined();
  });

  test('a connection aims at the next line quay, and only the last leg carries an exit', () => {
    const sections = apply(
      [
        transit(['stop_point:IDFM:21958', 'stop_point:IDFM:463060']),
        { ...walk(), type: 'transfer' },
        transit(['stop_point:IDFM:22087', 'stop_point:IDFM:22010']),
        walk(),
      ],
      PLACE_DU_CHATELET
    );

    expect(sections[0]!.boardingPosition).toMatchObject({ reason: 'transfer', car: 5 });
    expect(sections[0]!.exit).toBeUndefined();
    // The second leg alights somewhere with no exit in the snapshot.
    expect(sections[2]!.exit).toBeUndefined();
    expect(sections[2]!.boardingPosition).toBeUndefined();
  });

  test('the GTFS fallback still gets an exit, never a carriage', () => {
    // The local planner resolves stops to canonical stations, so no quay matches.
    const sections = apply([transit(['IDFM:71410', 'IDFM:71264']), walk()], PLACE_DU_CHATELET);

    expect(sections[0]!.exit!.id).toBe('IDFM:50147797');
    expect(sections[0]!.boardingPosition).toBeUndefined();
  });

  test('leaves a journey untouched when nothing is known about its stations', () => {
    const sections = [transit(['stop_point:IDFM:1', 'stop_point:IDFM:2']), walk()];
    const result = applyWayfinding(journey(sections), PLACE_DU_CHATELET, SNAPSHOT);

    expect(result.sections).toBe(sections);
  });

  test('leaves a walk-only journey untouched', () => {
    const sections = [walk()];
    expect(applyWayfinding(journey(sections), PLACE_DU_CHATELET, SNAPSHOT).sections).toBe(sections);
  });
});

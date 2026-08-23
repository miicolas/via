import { describe, expect, test } from 'bun:test';

import { parseElevatorRows } from './parse-elevators';

describe('parseElevatorRows', () => {
  test('maps PRIM rows to canonical stations and normalized equipment states', () => {
    expect(parseElevatorRows([
      {
        liftid: 'lift-42',
        zdcid: '71410',
        privateelevatorid: 'RATP-42',
        liftsituation: 'Entrée rue de Rivoli vers quai',
        liftdirection: 'Direction La Défense',
        liftstatus: 'notavailable',
        liftreason: 'liftFailure',
        liftstateupdate: '2026-08-23T14:30:00+02:00',
      },
    ])).toEqual([
      {
        id: 'lift-42',
        stopId: 'IDFM:71410',
        privateId: 'RATP-42',
        situation: 'Entrée rue de Rivoli vers quai',
        direction: 'Direction La Défense',
        status: 'notavailable',
        reason: 'liftFailure',
        stateUpdatedAt: new Date('2026-08-23T12:30:00.000Z'),
      },
    ]);
  });

  test('keeps the latest duplicate and clears an obsolete reason once available', () => {
    const rows = parseElevatorRows([
      {
        liftId: 'lift-1',
        ZdCId: 'IDFM:1',
        liftStatus: 'notavailable',
        liftReason: 'closedForMaintenance',
        liftStateUpdate: '2026-08-23T09:30:00Z',
      },
      {
        liftId: 'lift-1',
        ZdCId: 'stop_area:IDFM:1',
        liftStatus: 'AVAILABLE',
        liftReason: 'closedForMaintenance',
        liftStateUpdate: '2026-08-23T14:30:00Z',
      },
    ]);

    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({
      id: 'lift-1',
      stopId: 'IDFM:1',
      status: 'available',
      reason: null,
    });
  });

  test('drops unknown statuses and rejects an empty unauthenticated export', () => {
    expect(parseElevatorRows([{ liftid: 'lift-1', zdcid: '1', liftstatus: 'broken' }]))
      .toEqual([]);
    expect(parseElevatorRows([])).toEqual([]);
    expect(() => parseElevatorRows({ records: [] })).toThrow(
      'Elevator source payload is not an array'
    );
  });
});

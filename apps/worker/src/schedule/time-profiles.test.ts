import { describe, expect, test } from 'bun:test';

import type { PositionalCsv } from '../csv';
import type { ScheduledTrip } from './import-schedules';
import { buildTimeProfiles, STOP_TIME_COLUMNS, type StopTimeColumn } from './time-profiles';

type CsvRow = Record<string, string>;

/**
 * Cases stay written by column name — the build reads positions, but a test
 * that spelled its rows as bare arrays would say nothing about which field is
 * which.
 */
function rowsOf(rows: CsvRow[]): PositionalCsv<StopTimeColumn> {
  const column = Object.fromEntries(
    STOP_TIME_COLUMNS.map((name, index) => [name, index])
  ) as Record<StopTimeColumn, number>;

  async function* generate(): AsyncGenerator<readonly string[]> {
    for (const row of rows) yield STOP_TIME_COLUMNS.map((name) => row[name] ?? '');
  }

  return { column, rows: generate() };
}

function tripOf(numericId: number, id: string, routeId = 'route-a'): ScheduledTrip {
  return {
    numericId,
    id,
    routeId,
    directionId: 0,
    headsign: 'Terminus',
    serviceId: 'service-1',
    shapeId: 'shape-1',
  };
}

function call(tripId: string, sequence: number, stopId: string, time: string): CsvRow {
  return {
    trip_id: tripId,
    stop_sequence: String(sequence),
    stop_id: stopId,
    arrival_time: time,
    departure_time: time,
  };
}

function build(
  rows: CsvRow[],
  trips: Map<string, ScheduledTrip>,
  stopKeys: ReadonlyMap<string, number>,
  canonicalStopIdOf: (stopId: string) => string = (stopId) => stopId
) {
  return buildTimeProfiles({
    stopTimes: rowsOf(rows),
    trips,
    canonicalStopIdOf,
    stopKeyById: stopKeys,
  });
}

const STOP_KEYS = new Map([
  ['stop-a', 1],
  ['stop-b', 2],
  ['stop-c', 3],
]);

describe('buildTimeProfiles', () => {
  test('groups a trip and expresses its calls relative to the first departure', async () => {
    const trips = new Map([['t1', tripOf(1, 't1')]]);
    const result = await build(
      [
        call('t1', 1, 'stop-a', '08:00:00'),
        call('t1', 2, 'stop-b', '08:05:00'),
        call('t1', 3, 'stop-c', '08:12:30'),
      ],
      trips,
      STOP_KEYS
    );

    expect(result.profileCount).toBe(1);
    expect(result.callsForTrip(1)).toEqual([
      { stopKey: 1, arrivalOffset: 0, departureOffset: 0 },
      { stopKey: 2, arrivalOffset: 300, departureOffset: 300 },
      { stopKey: 3, arrivalOffset: 750, departureOffset: 750 },
    ]);
    expect(result.assignmentForTrip(1)).toEqual({ profileKey: 1, startSeconds: 8 * 3600 });
    expect(result.stats.departureCount).toBe(3);
  });

  test('sorts a block by numeric stop_sequence before computing offsets', async () => {
    const trips = new Map([['t1', tripOf(1, 't1')]]);
    const result = await build(
      [
        call('t1', 10, 'stop-b', '09:10:00'),
        call('t1', 2, 'stop-a', '09:00:00'),
      ],
      trips,
      STOP_KEYS
    );

    expect(result.callsForTrip(1)).toEqual([
      { stopKey: 1, arrivalOffset: 0, departureOffset: 0 },
      { stopKey: 2, arrivalOffset: 600, departureOffset: 600 },
    ]);
    expect(result.assignmentForTrip(1)?.startSeconds).toBe(9 * 3600);
  });

  test('trips with identical offset vectors share one profile', async () => {
    const trips = new Map([
      ['early', tripOf(1, 'early')],
      ['late', tripOf(2, 'late')],
      ['longer', tripOf(3, 'longer')],
    ]);
    const result = await build(
      [
        call('early', 1, 'stop-a', '06:00:00'),
        call('early', 2, 'stop-b', '06:04:00'),
        call('late', 1, 'stop-a', '11:30:00'),
        call('late', 2, 'stop-b', '11:34:00'),
        call('longer', 1, 'stop-a', '06:00:00'),
        call('longer', 2, 'stop-b', '06:05:00'),
      ],
      trips,
      STOP_KEYS
    );

    expect(result.profileCount).toBe(2);
    expect(result.assignmentForTrip(1)?.profileKey).toBe(result.assignmentForTrip(2)?.profileKey);
    expect(result.assignmentForTrip(3)?.profileKey).not.toBe(result.assignmentForTrip(1)?.profileKey);
    expect(result.assignmentForTrip(2)?.startSeconds).toBe(11 * 3600 + 30 * 60);
  });

  test('keeps a first-call arrival earlier than its departure and >24h times', async () => {
    const trips = new Map([['night', tripOf(1, 'night')]]);
    const result = await build(
      [
        {
          trip_id: 'night',
          stop_sequence: '1',
          stop_id: 'stop-a',
          arrival_time: '23:58:00',
          departure_time: '24:00:00',
        },
        {
          trip_id: 'night',
          stop_sequence: '2',
          stop_id: 'stop-b',
          arrival_time: '25:15:00',
          departure_time: '25:15:00',
        },
      ],
      trips,
      STOP_KEYS
    );

    const start = 24 * 3600;
    expect(result.assignmentForTrip(1)?.startSeconds).toBe(start);
    expect(result.callsForTrip(1)).toEqual([
      { stopKey: 1, arrivalOffset: -120, departureOffset: 0 },
      {
        stopKey: 2,
        arrivalOffset: 25 * 3600 + 900 - start,
        departureOffset: 25 * 3600 + 900 - start,
      },
    ]);
  });

  test('preserves the legacy skip semantics and side effects', async () => {
    const trips = new Map([['t1', tripOf(1, 't1', 'route-x')]]);
    const result = await build(
      [
        call('ghost', 1, 'stop-a', '07:00:00'),
        { trip_id: 't1', stop_sequence: '1', stop_id: 'stop-a', arrival_time: '', departure_time: '' },
        call('t1', 2, 'unknown-stop', '07:01:00'),
        { trip_id: 't1', stop_sequence: '3', stop_id: 'platform-b', arrival_time: '07:02:00', departure_time: '' },
      ],
      trips,
      STOP_KEYS,
      (stopId) => (stopId === 'platform-b' ? 'stop-b' : stopId)
    );

    expect(result.stats.skippedStops).toBe(1);
    expect(result.stats.departureCount).toBe(1);
    expect([...result.stopRoutePairs.values()]).toEqual([{ stopId: 'stop-b', routeId: 'route-x' }]);
    // The only kept call: arrival backfills the missing departure.
    expect(result.callsForTrip(1)).toEqual([
      { stopKey: 2, arrivalOffset: 0, departureOffset: 0 },
    ]);
    expect(result.assignmentForTrip(1)?.startSeconds).toBe(7 * 3600 + 120);
  });

  test('a trip with no usable call gets no profile assignment', async () => {
    const trips = new Map([
      ['empty', tripOf(1, 'empty')],
      ['kept', tripOf(2, 'kept')],
    ]);
    const result = await build(
      [
        call('empty', 1, 'unknown-stop', '05:00:00'),
        call('kept', 1, 'stop-a', '05:00:00'),
      ],
      trips,
      STOP_KEYS
    );

    expect(result.assignmentForTrip(1)).toBeUndefined();
    expect(result.assignmentForTrip(2)?.profileKey).toBe(1);
  });

  test('throws when a flushed trip reappears later in the file', async () => {
    const trips = new Map([
      ['t1', tripOf(1, 't1')],
      ['t2', tripOf(2, 't2')],
    ]);
    await expect(
      build(
        [
          call('t1', 1, 'stop-a', '06:00:00'),
          call('t2', 1, 'stop-a', '06:10:00'),
          call('t1', 2, 'stop-b', '06:20:00'),
        ],
        trips,
        STOP_KEYS
      )
    ).rejects.toThrow('not grouped by trip: t1');
  });

  test('throws on a duplicate stop_sequence within one trip', async () => {
    const trips = new Map([['t1', tripOf(1, 't1')]]);
    await expect(
      build(
        [call('t1', 4, 'stop-a', '06:00:00'), call('t1', 4, 'stop-b', '06:05:00')],
        trips,
        STOP_KEYS
      )
    ).rejects.toThrow('Duplicate stop_sequence 4');
  });
});

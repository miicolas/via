import { expect, test } from 'bun:test';
import type { Journey, JourneyMode } from '@via/contract';

import { elevatorSourceStatusFromTimestamps } from '../elevators';
import { journeyHasOperationalElevators } from './elevators';

test('expires a lift snapshot when the scheduled import has not refreshed it', () => {
  const now = new Date('2026-08-23T18:00:00Z');
  expect(elevatorSourceStatusFromTimestamps(
    new Date('2026-08-23T17:00:00Z'),
    new Date('2026-08-23T14:30:00Z'),
    now
  ).status).toBe('ok');
  expect(elevatorSourceStatusFromTimestamps(
    new Date('2026-08-22T04:00:00Z'),
    new Date('2026-08-22T03:30:00Z'),
    now
  ).status).toBe('unavailable');
});

test('keeps a rail journey only when every referenced station lift is available', () => {
  const journey = journeyUsing('rer');
  const canonical = new Map([
    ['origin-stop', 'IDFM:origin'],
    ['destination-stop', 'IDFM:destination'],
  ]);

  expect(journeyHasOperationalElevators(journey, canonical, new Map([
    ['IDFM:origin', ['available']],
    ['IDFM:destination', ['available', 'available']],
  ]))).toBe(true);

  expect(journeyHasOperationalElevators(journey, canonical, new Map([
    ['IDFM:origin', ['available']],
    ['IDFM:destination', ['available', 'notavailable']],
  ]))).toBe(false);
});

test('rejects missing or unknown lift data, but leaves surface-only routes alone', () => {
  const canonical = new Map([
    ['origin-stop', 'IDFM:origin'],
    ['destination-stop', 'IDFM:destination'],
  ]);

  expect(journeyHasOperationalElevators(journeyUsing('metro'), canonical, new Map([
    ['IDFM:origin', ['available']],
  ]))).toBe(false);
  expect(journeyHasOperationalElevators(journeyUsing('metro'), canonical, new Map([
    ['IDFM:origin', ['available']],
    ['IDFM:destination', ['unknown']],
  ]))).toBe(false);
  expect(journeyHasOperationalElevators(journeyUsing('bus'), new Map(), new Map())).toBe(true);
});

function journeyUsing(mode: JourneyMode): Journey {
  return {
    id: mode,
    qualifier: 'recommended',
    durationSeconds: 600,
    walkingDurationSeconds: 0,
    transferCount: 0,
    departureAt: '2026-08-21T10:00:00Z',
    arrivalAt: '2026-08-21T10:10:00Z',
    status: 'normal',
    warnings: [],
    sections: [{
      type: 'transit',
      durationSeconds: 600,
      from: { name: 'Origine', coordinate: { latitude: 48.8, longitude: 2.3 } },
      to: { name: 'Destination', coordinate: { latitude: 48.9, longitude: 2.4 } },
      geometry: [],
      route: {
        id: mode,
        shortName: '1',
        longName: mode,
        mode,
        color: '#000000',
        textColor: '#FFFFFF',
      },
      stops: [
        {
          id: 'origin-stop',
          name: 'Origine',
          coordinate: { latitude: 48.8, longitude: 2.3 },
        },
        {
          id: 'destination-stop',
          name: 'Destination',
          coordinate: { latitude: 48.9, longitude: 2.4 },
        },
      ],
    }],
  };
}

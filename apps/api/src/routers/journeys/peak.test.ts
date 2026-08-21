import { expect, test } from 'bun:test';
import type { Journey } from '@via/contract';

import { transferCandidates } from './peak';

test('only marks the last rail stop before a later transit section', () => {
  const journey: Journey = {
    id: 'journey',
    qualifier: 'recommended',
    durationSeconds: 1_800,
    walkingDurationSeconds: 120,
    transferCount: 1,
    departureAt: '2026-08-21T16:00:00Z',
    arrivalAt: '2026-08-21T16:30:00Z',
    status: 'normal',
    warnings: [],
    sections: [
      {
        type: 'transit',
        durationSeconds: 900,
        from: { name: 'Gare du Nord', coordinate: { latitude: 48.88, longitude: 2.35 } },
        to: { name: 'Châtelet', coordinate: { latitude: 48.86, longitude: 2.35 } },
        geometry: [],
        route: {
          id: 'metro-4',
          shortName: '4',
          longName: 'Métro 4',
          mode: 'metro',
          color: '#000',
          textColor: '#fff',
        },
        stops: [
          {
            id: 'origin',
            name: 'Gare du Nord',
            coordinate: { latitude: 48.88, longitude: 2.35 },
            arrivalAt: '2026-08-21T16:00:00Z',
          },
          {
            id: 'transfer',
            name: 'Châtelet',
            coordinate: { latitude: 48.86, longitude: 2.35 },
            arrivalAt: '2026-08-21T16:15:00Z',
          },
        ],
      },
      {
        type: 'transfer',
        durationSeconds: 120,
        from: { name: 'Châtelet', coordinate: { latitude: 48.86, longitude: 2.35 } },
        to: { name: 'Châtelet', coordinate: { latitude: 48.86, longitude: 2.35 } },
        geometry: [],
        stops: [],
      },
      {
        type: 'transit',
        durationSeconds: 780,
        from: { name: 'Châtelet', coordinate: { latitude: 48.86, longitude: 2.35 } },
        to: { name: 'Nation', coordinate: { latitude: 48.85, longitude: 2.4 } },
        geometry: [],
        route: {
          id: 'rer-a',
          shortName: 'A',
          longName: 'RER A',
          mode: 'rer',
          color: '#000',
          textColor: '#fff',
        },
        stops: [],
      },
    ],
  };

  expect(transferCandidates(journey)).toEqual([{
    rawID: 'transfer',
    stationName: 'Châtelet',
    arrivalAt: '2026-08-21T16:15:00Z',
  }]);
});

test('does not mark a rail section when no later transit section follows', () => {
  const journey = {
    sections: [{
      type: 'transit' as const,
      route: { mode: 'metro' as const },
      stops: [{ id: 'terminal', name: 'Terminal', coordinate: { latitude: 48.8, longitude: 2.3 } }],
    }],
  } as Journey;

  expect(transferCandidates(journey)).toEqual([]);
});

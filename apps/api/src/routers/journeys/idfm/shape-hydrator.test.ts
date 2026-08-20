import { expect, test } from 'bun:test';
import type { Journey } from '@via/contract';

import { hydrateSparseJourneyGeometry } from './shape-hydrator';

const from = { latitude: 48.861, longitude: 2.347 };
const to = { latitude: 48.8918, longitude: 2.238 };

test('replaces stop-to-stop chords with the matching detailed GTFS shape', async () => {
  const journey: Journey = {
    id: 'rer-a',
    qualifier: 'recommended',
    durationSeconds: 600,
    walkingDurationSeconds: 0,
    transferCount: 0,
    departureAt: '2026-08-20T10:00:00.000Z',
    arrivalAt: '2026-08-20T10:10:00.000Z',
    status: 'normal',
    warnings: [],
    sections: [{
      type: 'transit',
      durationSeconds: 600,
      from: { name: 'Châtelet - Les Halles', coordinate: from },
      to: { name: 'La Défense', coordinate: to },
      geometry: [
        from,
        { latitude: 48.875, longitude: 2.327 },
        { latitude: 48.887, longitude: 2.28 },
        to,
      ],
      route: {
        id: 'A',
        shortName: 'A',
        longName: 'RER A',
        mode: 'rer',
        color: '#E3051C',
        textColor: '#FFFFFF',
      },
      stops: [
        { id: 'chatelet', name: 'Châtelet', coordinate: from },
        {
          id: 'auber',
          name: 'Auber',
          coordinate: { latitude: 48.872, longitude: 2.329 },
        },
        {
          id: 'etoile',
          name: 'Charles de Gaulle - Étoile',
          coordinate: { latitude: 48.874, longitude: 2.295 },
        },
        { id: 'defense', name: 'La Défense', coordinate: to },
      ],
    }],
  };
  const detailedShape = [
    from,
    { latitude: 48.862, longitude: 2.343 },
    { latitude: 48.868, longitude: 2.338 },
    { latitude: 48.872, longitude: 2.329 },
    { latitude: 48.874, longitude: 2.295 },
    { latitude: 48.885, longitude: 2.255 },
    to,
  ];

  const [hydrated] = await hydrateSparseJourneyGeometry([journey], async (requests) => {
    expect(requests).toEqual([{ mode: 'rer', shortName: 'A' }]);
    return [{ mode: 'rer', shortName: 'A', coordinates: detailedShape }];
  });

  expect(hydrated.sections[0]?.geometry).toEqual(detailedShape);
});

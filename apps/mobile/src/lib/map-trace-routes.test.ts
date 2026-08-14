import type { NetworkRoute } from '@via/contract';
import { expect, test } from 'bun:test';

import { mapTraceRoutes } from './map-trace-routes';

function route(id: string, mode: NetworkRoute['mode']): NetworkRoute {
  return {
    id,
    shortName: id,
    color: '#000000',
    textColor: '#FFFFFF',
    mode,
    segments: [
      {
        id: `${id}-shape`,
        coordinates: [
          { latitude: 48.85, longitude: 2.34 },
          { latitude: 48.86, longitude: 2.35 },
        ],
      },
    ],
  };
}

test('draws metro and RER tracks but never a bus track', () => {
  const metro = route('1', 'metro');
  const rer = route('A', 'rer');
  const bus = route('91', 'bus');

  expect(mapTraceRoutes([metro, rer, bus])).toEqual([metro, rer]);
});

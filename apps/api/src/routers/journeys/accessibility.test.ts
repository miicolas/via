import { expect, test } from 'bun:test';
import type { Journey, JourneyMode } from '@via/contract';

import { usedStationIDs } from './accessibility';

test('does not require rail-station facts for a wheelchair bus detour', () => {
  expect(usedStationIDs(journeyUsing('bus'))).toEqual([]);
});

test('keeps checking the boarding and alighting stations of rail sections', () => {
  expect(usedStationIDs(journeyUsing('rer'))).toEqual(['origin-stop', 'destination-stop']);
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

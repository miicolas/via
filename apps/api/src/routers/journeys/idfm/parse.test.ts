import { expect, test } from 'bun:test';
import type { JourneyInput } from '@via/contract';

import { parseIdfmJourneys } from './parse';

const input: JourneyInput = {
  origin: { latitude: 48.8566, longitude: 2.3522 },
  destination: {
    kind: 'address',
    id: 'destination',
    name: '7 Allée Verte',
    coordinate: { latitude: 48.859559, longitude: 2.370737 },
  },
  limit: 2,
};

test('normalizes Navitia and enforces the requested result limit', () => {
  const row = (minute: number) => ({
    departure_date_time: `20260813T20${String(minute).padStart(2, '0')}00`,
    arrival_date_time: `20260813T20${String(minute + 5).padStart(2, '0')}00`,
    duration: 300,
    sections: [
      {
        type: 'street_network',
        duration: 300,
        from: { name: 'Ma position' },
        to: { name: '7 Allée Verte' },
      },
    ],
  });

  const journeys = parseIdfmJourneys(
    { journeys: [row(0), row(10), row(20)] },
    input,
    new Date('2026-08-13T20:00:00+02:00')
  );

  expect(journeys).toHaveLength(2);
  expect(journeys[0]?.sections[0]?.type).toBe('walk');
  expect(journeys.map((journey) => journey.qualifier)).toEqual(['recommended', 'walking']);
});

test('keeps the road geometry of a walking section, including multiple line parts', () => {
  const journeys = parseIdfmJourneys(
    {
      journeys: [
        {
          departure_date_time: '20260813T200000',
          arrival_date_time: '20260813T200500',
          duration: 300,
          sections: [
            {
              type: 'street_network',
              duration: 300,
              from: { name: 'Ma position', coord: { lon: 2.3522, lat: 48.8566 } },
              to: { name: '7 Allée Verte', coord: { lon: 2.370737, lat: 48.859559 } },
              geojson: {
                type: 'MultiLineString',
                coordinates: [
                  [
                    [2.3522, 48.8566],
                    [2.356, 48.8574],
                  ],
                  [
                    [2.356, 48.8574],
                    [2.370737, 48.859559],
                  ],
                ],
              },
            },
          ],
        },
      ],
    },
    input,
    new Date('2026-08-13T20:00:00+02:00')
  );

  expect(journeys[0]?.sections[0]?.geometry).toEqual([
    { latitude: 48.8566, longitude: 2.3522 },
    { latitude: 48.8574, longitude: 2.356 },
    { latitude: 48.8574, longitude: 2.356 },
    { latitude: 48.859559, longitude: 2.370737 },
  ]);
});

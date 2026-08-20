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

test('uses the ordered transit stops when IDFM omits a line geometry', () => {
  const journeys = parseIdfmJourneys(
    {
      journeys: [
        {
          departure_date_time: '20260813T200000',
          arrival_date_time: '20260813T201000',
          duration: 600,
          sections: [
            {
              type: 'public_transport',
              duration: 600,
              departure_date_time: '20260813T200000',
              arrival_date_time: '20260813T201000',
              from: { name: 'Hôtel de Ville', coord: { lon: 2.3522, lat: 48.8566 } },
              to: { name: 'Bastille', coord: { lon: 2.369, lat: 48.853 } },
              display_informations: {
                code: '76',
                name: 'Bus 76',
                commercial_mode: 'Bus',
              },
              stop_date_times: [
                {
                  stop_point: {
                    id: 'hotel-de-ville',
                    name: 'Hôtel de Ville',
                    coord: { lon: 2.3522, lat: 48.8566 },
                  },
                },
                {
                  stop_point: {
                    id: 'saint-paul',
                    name: 'Saint-Paul',
                    coord: { lon: 2.3601, lat: 48.8552 },
                  },
                },
                {
                  stop_point: {
                    id: 'bastille',
                    name: 'Bastille',
                    coord: { lon: 2.369, lat: 48.853 },
                  },
                },
              ],
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
    { latitude: 48.8552, longitude: 2.3601 },
    { latitude: 48.853, longitude: 2.369 },
  ]);
});

test('distinguishes tram and Transilien sections from Navitia commercial modes', () => {
  const transitSection = (commercialMode: string, code: string, minute: number) => ({
    type: 'public_transport',
    duration: 300,
    departure_date_time: `20260813T20${String(minute).padStart(2, '0')}00`,
    arrival_date_time: `20260813T20${String(minute + 5).padStart(2, '0')}00`,
    from: { name: 'Origine', coord: { lon: 2.3522, lat: 48.8566 } },
    to: { name: 'Destination', coord: { lon: 2.370737, lat: 48.859559 } },
    display_informations: {
      code,
      name: code,
      commercial_mode: commercialMode,
      color: '336699',
      text_color: 'FFFFFF',
    },
  });
  const journeys = parseIdfmJourneys(
    {
      journeys: [
        {
          departure_date_time: '20260813T200000',
          arrival_date_time: '20260813T201000',
          duration: 600,
          sections: [
            transitSection('Tramway', 'T1', 0),
            transitSection('Train Transilien', 'J', 5),
          ],
        },
      ],
    },
    input,
    new Date('2026-08-13T20:00:00+02:00')
  );

  expect(journeys[0]?.sections.map((section) => section.route?.mode)).toEqual([
    'tram',
    'transilien',
  ]);
});

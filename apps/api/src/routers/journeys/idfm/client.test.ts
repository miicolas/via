import { expect, test } from 'bun:test';
import type { JourneyInput } from '@via/contract';

import { journeyUrl } from './client';

test('sends exact arrival time and modal constraints to IDFM', () => {
  const input: JourneyInput = {
    origin: { latitude: 48.8566, longitude: 2.3522 },
    destination: {
      kind: 'station',
      id: 'north',
      name: 'Gare du Nord',
      coordinate: { latitude: 48.8809, longitude: 2.3553 },
    },
    limit: 4,
    requestedAt: '2026-10-25T09:30:00+01:00',
    datetimeRepresents: 'arrival',
    requiredModes: ['bus', 'tram', 'transilien'],
    excludedModes: ['rer', 'metro'],
  };
  const url = journeyUrl('https://example.test/journeys', input, new Date(input.requestedAt!));

  expect(url.searchParams.get('datetime')).toBe('20261025T093000');
  expect(url.searchParams.get('datetime_represents')).toBe('arrival');
  expect(url.searchParams.get('disable_geojson')).toBe('false');
  expect(url.searchParams.getAll('allowed_id[]')).toEqual([
    'physical_mode:Bus',
    'physical_mode:Tramway',
    'physical_mode:LocalTrain',
  ]);
  expect(url.searchParams.getAll('forbidden_uris[]')).toEqual([
    'physical_mode:RapidTransit',
    'physical_mode:Metro',
  ]);
});

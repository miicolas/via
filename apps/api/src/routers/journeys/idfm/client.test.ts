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
  expect(url.searchParams.getAll('direct_path_mode[]')).toEqual(['walking', 'bike']);
});

test('pins a PMR station journey to the selected stop areas', () => {
  const input: JourneyInput = {
    origin: { latitude: 48.8566, longitude: 2.3522 },
    originStationId: 'IDFM:71410',
    destination: {
      kind: 'station',
      id: 'IDFM:71264',
      name: 'Châtelet',
      coordinate: { latitude: 48.8584, longitude: 2.347 },
    },
    limit: 4,
    requiresAccessibleStations: true,
  };

  const url = journeyUrl('https://example.test/journeys', input, new Date('2026-08-20T08:00:00Z'));

  expect(url.searchParams.get('from')).toBe('stop_area:IDFM:71410');
  expect(url.searchParams.get('to')).toBe('stop_area:IDFM:71264');
  expect(url.searchParams.get('wheelchair')).toBe('true');
  // A step-free journey never advertises a bike alternative.
  expect(url.searchParams.getAll('direct_path_mode[]')).toEqual(['walking']);
});

test('preserves a Navitia-qualified stop point when pinning departure choices', () => {
  const input: JourneyInput = {
    origin: { latitude: 48.854, longitude: 2.35 },
    originStationId: 'stop_point:IDFM:22149',
    destination: {
      kind: 'station',
      id: 'IDFM:71264',
      name: 'Châtelet',
      coordinate: { latitude: 48.8584, longitude: 2.347 },
    },
    limit: 1,
  };

  const url = journeyUrl(
    'https://example.test/journeys',
    input,
    new Date('2026-08-23T12:00:00+02:00')
  );

  expect(url.searchParams.get('from')).toBe('stop_point:IDFM:22149');
});

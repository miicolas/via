import { expect, test } from 'bun:test';
import type { Journey } from '@via/contract';

import { crowdingCandidates } from './peak';

test('marks the platform boarded, the transfer and the one alighted at', () => {
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
            departureAt: '2026-08-21T16:00:00Z',
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
        stops: [
          {
            id: 'transfer-rer',
            name: 'Châtelet',
            coordinate: { latitude: 48.86, longitude: 2.35 },
            departureAt: '2026-08-21T16:17:00Z',
          },
          {
            id: 'arrival',
            name: 'Nation',
            coordinate: { latitude: 48.85, longitude: 2.4 },
            arrivalAt: '2026-08-21T16:30:00Z',
          },
        ],
      },
    ],
  };

  expect(crowdingCandidates(journey)).toEqual([
    { rawID: 'origin', stationName: 'Gare du Nord', at: '2026-08-21T16:00:00Z' },
    { rawID: 'transfer', stationName: 'Châtelet', at: '2026-08-21T16:15:00Z' },
    { rawID: 'transfer-rer', stationName: 'Châtelet', at: '2026-08-21T16:17:00Z' },
    { rawID: 'arrival', stationName: 'Nation', at: '2026-08-21T16:30:00Z' },
  ]);
});

test('marks a direct rail journey, which has no transfer to mark at all', () => {
  const journey = {
    sections: [{
      type: 'transit' as const,
      route: { mode: 'rer' as const },
      departureAt: '2026-08-21T08:11:00Z',
      arrivalAt: '2026-08-21T08:40:00Z',
      stops: [
        {
          id: 'juvisy',
          name: 'Juvisy',
          coordinate: { latitude: 48.68, longitude: 2.38 },
          departureAt: '2026-08-21T08:11:00Z',
        },
        {
          id: 'gare-du-nord',
          name: 'Gare du Nord',
          coordinate: { latitude: 48.88, longitude: 2.35 },
          arrivalAt: '2026-08-21T08:40:00Z',
        },
      ],
    }],
  } as Journey;

  expect(crowdingCandidates(journey)).toEqual([
    { rawID: 'juvisy', stationName: 'Juvisy', at: '2026-08-21T08:11:00Z' },
    { rawID: 'gare-du-nord', stationName: 'Gare du Nord', at: '2026-08-21T08:40:00Z' },
  ]);
});

test('falls back to the section times when the stop calls carry none', () => {
  const journey = {
    sections: [{
      type: 'transit' as const,
      route: { mode: 'metro' as const },
      departureAt: '2026-08-21T09:00:00Z',
      arrivalAt: '2026-08-21T09:12:00Z',
      stops: [
        { id: 'a', name: 'A', coordinate: { latitude: 48.8, longitude: 2.3 } },
        { id: 'b', name: 'B', coordinate: { latitude: 48.9, longitude: 2.4 } },
      ],
    }],
  } as Journey;

  expect(crowdingCandidates(journey)).toEqual([
    { rawID: 'a', stationName: 'A', at: '2026-08-21T09:00:00Z' },
    { rawID: 'b', stationName: 'B', at: '2026-08-21T09:12:00Z' },
  ]);
});

test('counts a single-call section once rather than at both of its ends', () => {
  const journey = {
    sections: [{
      type: 'transit' as const,
      route: { mode: 'metro' as const },
      departureAt: '2026-08-21T09:00:00Z',
      stops: [{ id: 'only', name: 'Only', coordinate: { latitude: 48.8, longitude: 2.3 } }],
    }],
  } as Journey;

  expect(crowdingCandidates(journey)).toEqual([
    { rawID: 'only', stationName: 'Only', at: '2026-08-21T09:00:00Z' },
  ]);
});

test('ignores bus and walking sections, which have no platform to fill', () => {
  const journey = {
    sections: [
      {
        type: 'walk' as const,
        stops: [],
      },
      {
        type: 'transit' as const,
        route: { mode: 'bus' as const },
        departureAt: '2026-08-21T09:00:00Z',
        stops: [{ id: 'stop', name: 'Arrêt', coordinate: { latitude: 48.8, longitude: 2.3 } }],
      },
    ],
  } as unknown as Journey;

  expect(crowdingCandidates(journey)).toEqual([]);
});

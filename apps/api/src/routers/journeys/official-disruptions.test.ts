import { describe, expect, test } from 'bun:test';
import type { Journey, JourneyInput, JourneysResponse } from '@via/contract';

import type { DisruptionsSnapshot } from '../lines/disruptions/snapshot';
import { applyOfficialDisruptions } from './official-disruptions';

const input: JourneyInput = {
  origin: { latitude: 48.86, longitude: 2.34 },
  destination: {
    kind: 'station',
    id: 'IDFM:destination',
    name: 'Destination',
    coordinate: { latitude: 48.88, longitude: 2.36 },
  },
  limit: 4,
};

describe('official disruption journey overlay', () => {
  test('removes a suspended journey when an unaffected official alternative exists', () => {
    const response = plan([
      journey('metro-4', 'IDFM:C01374', 'metro', 1_200),
      journey('bus-38', 'IDFM:C00038', 'bus', 1_500),
    ]);

    const result = applyOfficialDisruptions(
      response,
      input,
      snapshot('IDFM:C01374', 'suspended', 'Trafic interrompu'),
    );

    expect(result.journeys.map((value) => value.id)).toEqual(['bus-38']);
    expect(result.journeys[0]?.qualifier).toBe('recommended');
  });

  test('grounds a disruption warning in the official snapshot at the section time', () => {
    const response = plan([journey('metro-4', 'IDFM:C01374', 'metro', 1_200)]);

    const result = applyOfficialDisruptions(
      response,
      input,
      snapshot('IDFM:C01374', 'disrupted', 'Ralentissements sur la ligne 4'),
    );

    expect(result.journeys[0]).toMatchObject({
      status: 'disrupted',
      warnings: ['Ralentissements sur la ligne 4'],
    });
  });

  test('ignores a disruption whose official application period misses the journey', () => {
    const response = plan([journey('metro-4', 'IDFM:C01374', 'metro', 1_200)]);
    const future = snapshot('IDFM:C01374', 'suspended', 'Fermeture ce soir');
    future.disruptions[0]!.periods = [{ beginsAt: epoch('2026-08-26T20:00:00Z'), endsAt: epoch('2026-08-26T22:00:00Z') }];

    expect(applyOfficialDisruptions(response, input, future)).toEqual(response);
  });
});

function plan(journeys: Journey[]): JourneysResponse {
  return {
    status: 'ready',
    source: 'gtfs-theoretical',
    generatedAt: '2026-08-26T09:00:00Z',
    journeys,
  };
}

function journey(
  id: string,
  routeId: string,
  mode: 'metro' | 'bus',
  durationSeconds: number,
): Journey {
  return {
    id,
    qualifier: id === 'metro-4' ? 'recommended' : 'rapid',
    durationSeconds,
    walkingDurationSeconds: 120,
    transferCount: 0,
    departureAt: '2026-08-26T10:00:00Z',
    arrivalAt: '2026-08-26T10:20:00Z',
    status: 'theoretical',
    warnings: [],
    sections: [{
      id: `${id}-section`,
      type: 'transit',
      durationSeconds,
      from: { name: 'Départ', coordinate: { latitude: 48.86, longitude: 2.34 } },
      to: { name: 'Arrivée', coordinate: { latitude: 48.88, longitude: 2.36 } },
      departureAt: '2026-08-26T10:00:00Z',
      arrivalAt: '2026-08-26T10:20:00Z',
      geometry: [],
      route: {
        id: routeId,
        shortName: routeId.endsWith('1374') ? '4' : '38',
        longName: id,
        mode,
        color: '#000000',
        textColor: '#FFFFFF',
      },
      stops: [],
      timingSource: 'theoretical',
    }],
  };
}

function snapshot(
  routeId: string,
  severity: 'disrupted' | 'suspended',
  title: string,
): DisruptionsSnapshot {
  return {
    fetchedAt: epoch('2026-08-26T09:59:00Z'),
    disruptions: [{
      id: 'official-disruption',
      severity,
      title,
      routeIds: [routeId],
      periods: [{
        beginsAt: epoch('2026-08-26T09:30:00Z'),
        endsAt: epoch('2026-08-26T11:00:00Z'),
      }],
      impactedSections: [],
    }],
  };
}

function epoch(value: string) {
  return Math.floor(Date.parse(value) / 1_000);
}

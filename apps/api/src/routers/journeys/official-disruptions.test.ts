import { describe, expect, test } from 'bun:test';
import type { Journey, JourneyInput, JourneysResponse } from '@via/contract';

import { parseDisruptionsBulk } from '../lines/disruptions/parse';
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

  /**
   * The live "RER A : Nation du 29/06 au 30/08" payload names Nation only in
   * lines[].impactedObjects. Treating the absent impactedSections as a whole-
   * line closure erased every western RER A journey, including Chatou → Auber.
   */
  test('keeps a journey outside blocking works scoped to one station', () => {
    const response = plan([
      journey('rer-a-west', 'IDFM:C01742', 'rer', 1_200, ['Chatou - Croissy', 'Auber']),
    ]);

    const result = applyOfficialDisruptions(response, input, {
      fetchedAt: epoch('2026-08-26T09:59:00Z'),
      disruptions: nationWorks(),
    });

    expect(result.journeys.map((value) => value.id)).toEqual(['rer-a-west']);
  });

  test('removes a journey that serves the station named by blocking works', () => {
    const response = plan([
      journey('rer-a-nation', 'IDFM:C01742', 'rer', 1_200, ['Auber', 'Nation']),
    ]);

    const result = applyOfficialDisruptions(response, input, {
      fetchedAt: epoch('2026-08-26T09:59:00Z'),
      disruptions: nationWorks(),
    });

    expect(result.journeys).toEqual([]);
  });
});

function nationWorks() {
  return parseDisruptionsBulk({
    disruptions: [{
      id: 'nation-works',
      severity: 'BLOQUANTE',
      title: 'RER A : Nation du 29/06 au 30/08',
      applicationPeriods: [{ begin: '20260826T030000', end: '20260827T030000' }],
    }],
    lines: [{
      id: 'line:IDFM:C01742',
      impactedObjects: [
        {
          type: 'line',
          id: 'line:IDFM:C01742',
          name: 'A',
          disruptionIds: ['nation-works'],
        },
        {
          type: 'stop_point',
          id: 'stop_point:IDFM:monomodalStopPlace:473875',
          name: 'Nation',
          disruptionIds: ['nation-works'],
        },
      ],
    }],
  });
}

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
  mode: 'metro' | 'rer' | 'bus',
  durationSeconds: number,
  stopNames: string[] = [],
): Journey {
  const fromName = stopNames[0] ?? 'Départ';
  const toName = stopNames.at(-1) ?? 'Arrivée';
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
      from: { name: fromName, coordinate: { latitude: 48.86, longitude: 2.34 } },
      to: { name: toName, coordinate: { latitude: 48.88, longitude: 2.36 } },
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
      stops: stopNames.map((name, index) => ({
        id: `IDFM:stop-${index}`,
        name,
        coordinate: { latitude: 48.86 + index * 0.01, longitude: 2.34 + index * 0.01 },
      })),
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

import { describe, expect, test } from 'bun:test';

import {
  mapToiletFacts,
  parseToiletRows,
  type ToiletSourceRow,
  type ToiletStationCandidate,
} from './map-toilets';

const chatelet: ToiletStationCandidate = {
  id: 'IDFM:71264',
  name: 'Châtelet',
  latitude: 48.8583,
  longitude: 2.3470,
  routeShortNames: ['1', '4', '7', '11', '14', 'A', 'B', 'D'],
};

describe('parseToiletRows', () => {
  test('keeps positioned public toilets and translates source values', () => {
    expect(parseToiletRows([{
      ligne: 'A',
      station: 'Chatelet',
      accessible_au_public: 'oui',
      tarif_gratuit_payant: 'gratuit',
      en_zone_controlee: 'oui',
      accessibilite_pmr: 'non',
      localisation: '  Près de la sortie 3.  ',
      coord_geo: { lon: 2.3472, lat: 48.8581 },
    }])).toEqual([{
      stationName: 'Chatelet',
      lineShortName: 'A',
      latitude: 48.8581,
      longitude: 2.3472,
      price: 'free',
      wheelchairAccessible: false,
      controlledArea: true,
      location: 'Près de la sortie 3.',
      sourceRef: 'Chatelet:A:48.8581000:2.3472000',
    }]);
  });

  test('drops facilities that are not public or cannot be positioned', () => {
    expect(parseToiletRows([
      { ligne: 'A', station: 'Nation', accessible_au_public: 'non', coord_geo: { lon: 2.4, lat: 48.8 } },
      { ligne: 'A', station: 'Nation', accessible_au_public: 'oui' },
    ])).toEqual([]);
  });
});

describe('mapToiletFacts', () => {
  test('matches accents through the serving line and aggregates station facilities', () => {
    const rows: ToiletSourceRow[] = [
      facility({ location: 'Sortie 3.', wheelchairAccessible: true }),
      facility({
        lineShortName: '4',
        latitude: 48.8584,
        longitude: 2.3471,
        price: 'paid',
        controlledArea: false,
        location: 'Vers la ligne 4.',
        sourceRef: 'second',
      }),
    ];

    expect(mapToiletFacts(rows, [chatelet])).toEqual({
      facts: [{
        stopId: chatelet.id,
        detail:
          'Accès gratuit ou payant · Accessible PMR\n' +
          '• Sortie 3.\n' +
          '• Vers la ligne 4.',
        sourceRef: 'Chatelet:A:48.8581000:2.3472000|second',
      }],
      unmatched: [],
    });
  });

  test('uses proximity for a publisher name that differs from the canonical station', () => {
    const station: ToiletStationCandidate = {
      id: 'IDFM:71370',
      name: 'Gare Saint-Lazare',
      latitude: 48.8755,
      longitude: 2.3251,
      routeShortNames: ['3', '9', '12', '13', '14'],
    };
    const row = facility({
      stationName: 'Saint Lazare',
      lineShortName: '14',
      latitude: 48.8750,
      longitude: 2.3250,
    });

    expect(mapToiletFacts([row], [station]).facts[0]?.stopId).toBe(station.id);
  });

  test('accepts a nearby exact station name across a connecting concourse', () => {
    const wrongLine = { ...chatelet, routeShortNames: ['1'] };

    expect(mapToiletFacts([facility()], [wrongLine]).facts[0]?.stopId).toBe(chatelet.id);
  });

  test('does not match a facility beyond the safety radius', () => {
    const farAway = { ...chatelet, latitude: 48.9, longitude: 2.4 };

    expect(mapToiletFacts([facility()], [farAway]).unmatched).toHaveLength(1);
  });
});

function facility(overrides: Partial<ToiletSourceRow> = {}): ToiletSourceRow {
  return {
    stationName: 'Chatelet',
    lineShortName: 'A',
    latitude: 48.8581,
    longitude: 2.3472,
    price: 'free',
    wheelchairAccessible: true,
    controlledArea: true,
    location: undefined,
    sourceRef: 'Chatelet:A:48.8581000:2.3472000',
    ...overrides,
  };
}

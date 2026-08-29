import { describe, expect, test } from 'bun:test';

import {
  mapFountainFacts,
  parseFountainRows,
  type FountainSourceRow,
} from './map-fountains';

describe('parseFountainRows', () => {
  test('uses the canonical connection area and translates open-data values', () => {
    expect(parseFountainRows([{
      id: 61,
      zdcid: '73626',
      indisponible: 'NULL',
      accessible_pmr: 'true',
      remplissage_contenant_possible: 'oui',
      condition_acces: '  Hall voyageurs  ',
      adresse: 'NULL',
    }])).toEqual([{
      id: '61',
      stopId: 'IDFM:73626',
      isAvailable: true,
      unavailableSince: undefined,
      isWheelchairAccessible: true,
      canFillContainer: true,
      accessCondition: 'Hall voyageurs',
      address: undefined,
    }]);
  });

  test('marks a dated unavailability and drops rows without stable ids', () => {
    expect(parseFountainRows([
      { id: '8', zdcid: '71517', indisponible: '2026-08-01', accessible_pmr: false },
      { id: '9' },
      { zdcid: '71517' },
    ])).toEqual([{
      id: '8',
      stopId: 'IDFM:71517',
      isAvailable: false,
      unavailableSince: '2026-08-01',
      isWheelchairAccessible: false,
      canFillContainer: undefined,
      accessCondition: undefined,
      address: undefined,
    }]);
  });

  test('rejects duplicate fountain identities rather than replacing one silently', () => {
    expect(() => parseFountainRows([
      { id: 1, zdcid: '1' },
      { id: 1, zdcid: '2' },
    ])).toThrow('duplicate id 1');
  });
});

describe('mapFountainFacts', () => {
  test('aggregates a station and reports only the usable fountain qualities', () => {
    const rows: FountainSourceRow[] = [
      fountain({ id: '61' }),
      fountain({ id: '125', isAvailable: false, isWheelchairAccessible: false }),
    ];

    expect(mapFountainFacts(rows)).toEqual([{
      stopId: 'IDFM:73626',
      condition: 'available',
      detail:
        '1 fontaine disponible sur 2.\n' +
        'Accessible PMR · Remplissage de gourde possible\n' +
        'Emplacement précis non renseigné par Île-de-France Mobilités.',
      sourceRef: '125|61',
    }]);
  });

  test('keeps an unavailable station visible with the published address', () => {
    expect(mapFountainFacts([
      fountain({
        id: '8',
        stopId: 'IDFM:71517',
        isAvailable: false,
        unavailableSince: '2026-08-01',
        isWheelchairAccessible: false,
        canFillContainer: false,
        address: 'Parvis de La Défense',
      }),
    ])).toEqual([{
      stopId: 'IDFM:71517',
      condition: 'unavailable',
      detail:
        'Début de l’indisponibilité : 1 août 2026.\n' +
        'Non accessible PMR · Remplissage de gourde impossible\n' +
        'Adresse : Parvis de La Défense',
      sourceRef: '8',
    }]);
  });
});

function fountain(overrides: Partial<FountainSourceRow> = {}): FountainSourceRow {
  return {
    id: '61',
    stopId: 'IDFM:73626',
    isAvailable: true,
    unavailableSince: undefined,
    isWheelchairAccessible: true,
    canFillContainer: true,
    accessCondition: undefined,
    address: undefined,
    ...overrides,
  };
}

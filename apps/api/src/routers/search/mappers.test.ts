import { expect, test } from 'bun:test';

import { toStationResults } from './mappers';

test('rows become station results, coordinates numeric, badges built', () => {
  const results = toStationResults([
    {
      id: 'IDFM:462921',
      name: 'République',
      // The driver can hand geometry accessors back as strings.
      longitude: '2.3633' as unknown as number,
      latitude: '48.8675' as unknown as number,
      accessibilityCondition: null,
      accessibilityDetail: null,
      routes: [
        { id: 'IDFM:C01373', shortName: '3', routeType: 1, color: '837902', textColor: 'FFFFFF' },
        { id: 'IDFM:C01377', shortName: '11', routeType: 1, color: '8D5E2A', textColor: 'FFFFFF' },
      ],
    },
  ]);

  expect(results).toEqual([
    {
      kind: 'station',
      id: 'IDFM:462921',
      name: 'République',
      coordinate: { latitude: 48.8675, longitude: 2.3633 },
      routes: [
        {
          id: 'IDFM:C01373',
          shortName: '3',
          mode: 'metro',
          color: '#837902',
          textColor: '#FFFFFF',
        },
        {
          id: 'IDFM:C01377',
          shortName: '11',
          mode: 'metro',
          color: '#8D5E2A',
          textColor: '#FFFFFF',
        },
      ],
    },
  ]);
});

test('station facts use the shared accessibility label and detail', () => {
  const [result] = toStationResults([
    {
      id: 'IDFM:462921',
      name: 'République',
      longitude: 2.3633,
      latitude: 48.8675,
      routes: [],
      accessibilityCondition: 'staffAssistance',
      accessibilityDetail: 'Présence requise aux heures d’ouverture',
    },
  ]);

  expect(result?.accessibility).toEqual({
    condition: 'staffAssistance',
    label: 'Avec un agent',
    comment: 'Présence requise aux heures d’ouverture',
  });
});

test('orders rail badges before bus badges for compact station results', () => {
  const [result] = toStationResults([
    {
      id: 'IDFM:64483',
      name: 'Chatou - Croissy',
      longitude: 2.1553,
      latitude: 48.8851,
      accessibilityCondition: null,
      accessibilityDetail: null,
      routes: [
        { id: 'bus-6450', shortName: '6450', routeType: 3, color: '666666', textColor: 'FFFFFF' },
        { id: 'bus-6430', shortName: '6430', routeType: 3, color: '666666', textColor: 'FFFFFF' },
        { id: 'bus-6439', shortName: '6439', routeType: 3, color: '666666', textColor: 'FFFFFF' },
        { id: 'rer-a', shortName: 'A', routeType: 2, color: 'EB2132', textColor: 'FFFFFF' },
      ],
    },
  ]);

  expect(result?.routes.slice(0, 3).map((route) => route.shortName)).toEqual([
    'A',
    '6430',
    '6439',
  ]);
});

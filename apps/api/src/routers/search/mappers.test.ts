import { expect, test } from 'bun:test';

import { toStationResults } from './mappers';

test('rows become station results, coordinates numeric', () => {
  const results = toStationResults([
    {
      id: 'IDFM:462921',
      name: 'République',
      // The driver can hand geometry accessors back as strings.
      longitude: '2.3633' as unknown as number,
      latitude: '48.8675' as unknown as number,
      routeIds: ['IDFM:C01373', 'IDFM:C01377'],
    },
  ]);

  expect(results).toEqual([
    {
      kind: 'station',
      id: 'IDFM:462921',
      name: 'République',
      coordinate: { latitude: 48.8675, longitude: 2.3633 },
      routeIds: ['IDFM:C01373', 'IDFM:C01377'],
    },
  ]);
});

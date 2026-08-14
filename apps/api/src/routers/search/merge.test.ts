import { expect, test } from 'bun:test';
import type { AddressSearchResult, StationSearchResult } from '@via/contract';

import { mergeSearchResults } from './merge';

const republique: StationSearchResult = {
  kind: 'station',
  id: 'IDFM:71311',
  name: 'République',
  coordinate: { latitude: 48.8676, longitude: 2.3641 },
  routes: [
    { id: 'IDFM:C01373', shortName: '3', mode: 'metro', color: '#837902', textColor: '#FFFFFF' },
  ],
};

const rivoli12: AddressSearchResult = {
  kind: 'address',
  id: '75104_8249_00012',
  name: '12 Rue de Rivoli',
  context: '75004 Paris',
  coordinate: { latitude: 48.855602, longitude: 2.35995 },
};

test('a text query leads with stations', () => {
  const results = mergeSearchResults([republique], [rivoli12], { q: 'ré', limit: 10 });

  expect(results.map(({ kind }) => kind)).toEqual(['station', 'address']);
});

test('a query starting with a digit leads with addresses', () => {
  const results = mergeSearchResults([republique], [rivoli12], {
    q: '12 rue de rivoli',
    limit: 10,
  });

  expect(results.map(({ kind }) => kind)).toEqual(['address', 'station']);
});

test('with an origin every result carries a rounded distance', () => {
  const results = mergeSearchResults([republique], [rivoli12], {
    q: 'rivoli',
    limit: 10,
    origin: { latitude: 48.8676, longitude: 2.3641 },
  });

  expect(results[0].distanceMeters).toBe(0);
  expect(results[1].distanceMeters).toBeGreaterThan(1_300);
  expect(results[1].distanceMeters).toBeLessThan(1_450);
  expect(Number.isInteger(results[1].distanceMeters)).toBe(true);
});

test('without an origin no distance is invented', () => {
  const results = mergeSearchResults([republique], [rivoli12], { q: 'rivoli', limit: 10 });

  expect(results.every((result) => result.distanceMeters === undefined)).toBe(true);
});

test('the limit truncates the merged list', () => {
  const results = mergeSearchResults([republique], [rivoli12], { q: 'rivoli', limit: 1 });

  expect(results).toHaveLength(1);
});

import type { AddressSearchResult, StationSearchResult } from '@via/contract';
import { expect, mock, test } from 'bun:test';

const chatouCroissy: StationSearchResult = {
  kind: 'station',
  id: 'IDFM:stop:ChatouCroissy',
  name: 'Chatou - Croissy',
  coordinate: { latitude: 48.885, longitude: 2.156 },
  routes: [],
};

const roads: AddressSearchResult[] = [
  {
    kind: 'address',
    id: 'route-croissy-vesinet',
    name: 'Route de Croissy',
    context: '78110 Le Vésinet',
    coordinate: { latitude: 48.89, longitude: 2.14 },
  },
  {
    kind: 'address',
    id: 'route-croissy-pecq',
    name: 'Route de Croissy',
    context: '78230 Le Pecq',
    coordinate: { latitude: 48.9, longitude: 2.13 },
  },
];

mock.module('../search/search-places', () => ({
  searchPlaces: async () => ({
    results: [chatouCroissy, ...roads],
    banAvailable: true,
  }),
}));

const { placeResolver } = await import('./place-resolver');

test('resolves a station-like query in one shot instead of asking about address matches', async () => {
  await expect(placeResolver.resolve('Chatou-Croissy')).resolves.toEqual({
    status: 'resolved',
    result: chatouCroissy,
  });
});

test('treats a bare city name as its station rather than an address', async () => {
  for (const query of ['Chatou', 'Croissy']) {
    await expect(placeResolver.resolve(query)).resolves.toEqual({
      status: 'resolved',
      result: chatouCroissy,
    });
  }
});

test('keeps explicit street names in the address branch', async () => {
  await expect(placeResolver.resolve('Route de Croissy')).resolves.toEqual({
    status: 'ambiguous',
    candidates: roads,
  });
});

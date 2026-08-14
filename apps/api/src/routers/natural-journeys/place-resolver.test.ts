import type { AddressSearchResult, StationSearchResult } from '@via/contract';
import { expect, mock, test } from 'bun:test';

const chatouCroissy: StationSearchResult = {
  kind: 'station',
  id: 'IDFM:stop:ChatouCroissy',
  name: 'Chatou - Croissy',
  coordinate: { latitude: 48.885, longitude: 2.156 },
  routes: [],
};

const chatou: AddressSearchResult = {
  kind: 'address',
  id: '78146',
  name: 'Chatou',
  context: '78400 Chatou',
  coordinate: { latitude: 48.8966, longitude: 2.151 },
};

const carrieresSousPoissy: AddressSearchResult = {
  kind: 'address',
  id: '78123',
  name: 'Carrières-sous-Poissy',
  context: '78955 Carrières-sous-Poissy',
  coordinate: { latitude: 48.947611, longitude: 2.031689 },
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
  searchPlaces: async (query: string) => {
    if (/carri[eè]re/i.test(query)) {
      return {
        results: [carrieresSousPoissy, ...roads],
        municipalities: [carrieresSousPoissy],
        banAvailable: true,
      };
    }
    if (/route/i.test(query)) {
      return { results: [chatouCroissy, ...roads], municipalities: [], banAvailable: true };
    }
    return {
      results: [chatouCroissy, chatou, ...roads],
      municipalities: [chatou],
      banAvailable: true,
    };
  },
}));

const { placeResolver } = await import('./place-resolver');

test('resolves a station-like query in one shot instead of asking about address matches', async () => {
  await expect(placeResolver.resolve('Chatou-Croissy')).resolves.toEqual({
    status: 'resolved',
    result: chatouCroissy,
  });
});

test('treats a bare city name as the municipality centre', async () => {
  await expect(placeResolver.resolve('Chatou')).resolves.toEqual({
    status: 'resolved',
    result: chatou,
  });
});

test('accepts a fuzzy municipality match without asking for a street', async () => {
  await expect(placeResolver.resolve('Carrière sous Poissy')).resolves.toEqual({
    status: 'resolved',
    result: carrieresSousPoissy,
  });
});

test('keeps explicit street names in the address branch', async () => {
  await expect(placeResolver.resolve('Route de Croissy')).resolves.toEqual({
    status: 'ambiguous',
    candidates: roads,
  });
});

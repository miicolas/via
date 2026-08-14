import { describe, expect, test } from 'bun:test';
import type { AddressSearchResult, StationSearchResult } from '@via/contract';

import {
  MAX_RECENT_SEARCHES,
} from './recent-searches';
import { parseRecentSearches } from './parse-recent-searches';
import { rememberRecentSearch } from './remember-recent-search';
import { removeRecentSearch } from './remove-recent-search';
import { recentSearchKey } from './recent-search-key';
import { serializeRecentSearches } from './serialize-recent-searches';
import { toRecentSearchSnapshot } from './to-recent-search-snapshot';

const station: StationSearchResult = {
  kind: 'station',
  id: 'gare-de-lyon',
  name: 'Gare de Lyon',
  coordinate: { latitude: 48.8443, longitude: 2.3731 },
  routes: [
    { id: '1', shortName: '1', mode: 'metro', color: '#FFCD00', textColor: '#000000' },
  ],
  distanceMeters: 120,
};

const address: AddressSearchResult = {
  kind: 'address',
  id: 'ban:comptoir-general',
  name: 'Le Comptoir Général',
  context: '84 quai de Jemmapes, 75010 Paris',
  coordinate: { latitude: 48.8725, longitude: 2.3652 },
  distanceMeters: 900,
};

function stationWithId(id: string): StationSearchResult {
  return { ...station, id, name: id };
}

describe('recent searches', () => {
  test('stores only display and navigation data, never the distance', () => {
    expect(toRecentSearchSnapshot(station)).toEqual({
      kind: 'station',
      id: station.id,
      name: station.name,
      coordinate: station.coordinate,
      routes: station.routes,
    });
    expect(toRecentSearchSnapshot(address)).toEqual({
      kind: 'address',
      id: address.id,
      name: address.name,
      context: address.context,
      coordinate: address.coordinate,
    });
  });

  test('promotes an existing entry and deduplicates by kind and id', () => {
    const initial = [toRecentSearchSnapshot(address), toRecentSearchSnapshot(station)];

    const next = rememberRecentSearch(initial, station);

    expect(next.map(recentSearchKey)).toEqual(['station:gare-de-lyon', 'address:ban:comptoir-general']);
    expect(next).toHaveLength(2);
  });

  test(`keeps only the ${MAX_RECENT_SEARCHES} most recent entries`, () => {
    const entries = Array.from({ length: MAX_RECENT_SEARCHES + 2 }, (_, index) =>
      toRecentSearchSnapshot(stationWithId(`station-${index}`))
    );

    const next = entries.reduce(
      (current, entry) => rememberRecentSearch(current, entry),
      [] as ReturnType<typeof toRecentSearchSnapshot>[]
    );

    expect(next).toHaveLength(MAX_RECENT_SEARCHES);
    expect(next[0]?.id).toBe(`station-${MAX_RECENT_SEARCHES + 1}`);
    expect(next.at(-1)?.id).toBe('station-2');
  });

  test('removes one entry by its stable key', () => {
    const entries = [toRecentSearchSnapshot(station), toRecentSearchSnapshot(address)];

    expect(removeRecentSearch(entries, 'station:gare-de-lyon')).toEqual([
      toRecentSearchSnapshot(address),
    ]);
  });

  test('serializes a versioned envelope and rejects invalid storage', () => {
    const entries = [toRecentSearchSnapshot(station)];
    const serialized = serializeRecentSearches(entries);

    expect(serialized).toContain('"version":1');
    expect(parseRecentSearches(serialized)).toEqual(entries);
    expect(parseRecentSearches('{not-json')).toEqual([]);
    expect(parseRecentSearches(JSON.stringify({ version: 2, entries }))).toEqual([]);
    expect(parseRecentSearches(JSON.stringify({ version: 1, entries: [{ kind: 'station' }] }))).toEqual(
      []
    );
  });

  test('normalizes extra persisted fields before returning snapshots', () => {
    const value = JSON.stringify({
      version: 1,
      entries: [{ ...toRecentSearchSnapshot(station), distanceMeters: 999 }],
    });

    expect(parseRecentSearches(value)).toEqual([toRecentSearchSnapshot(station)]);
  });
});

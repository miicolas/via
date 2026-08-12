import { expect, test } from 'bun:test';
import type { SearchResponse } from '@via/contract';

import { searchState } from '@/features/home-map/model/search-state';

const response: SearchResponse = {
  results: [
    {
      kind: 'station',
      id: 'republique',
      name: 'République',
      coordinate: { latitude: 48.8675, longitude: 2.3638 },
      routeIds: ['line-5'],
    },
  ],
  sources: { ban: 'ok' },
};

test('an empty query is idle', () => {
  expect(searchState('  ')).toEqual({ status: 'idle', results: [], banUnavailable: false });
});

test('no completion yet means loading', () => {
  expect(searchState('répu').status).toBe('loading');
});

test('a completion for the current query is ready', () => {
  const state = searchState('répu', { forQuery: 'répu', response });

  expect(state.status).toBe('ready');
  expect(state.results).toHaveLength(1);
  expect(state.banUnavailable).toBe(false);
});

test('a stale completion keeps painting but reads as loading', () => {
  const state = searchState('républ', { forQuery: 'répu', response });

  expect(state.status).toBe('loading');
  expect(state.results).toHaveLength(1);
});

test('a failed completion for the current query is an error', () => {
  expect(searchState('répu', { forQuery: 'répu' }).status).toBe('error');
});

test('a degraded BAN is surfaced', () => {
  const degraded: SearchResponse = { ...response, sources: { ban: 'unavailable' } };

  expect(searchState('répu', { forQuery: 'répu', response: degraded }).banUnavailable).toBe(true);
});

test('the query is compared trimmed', () => {
  expect(searchState(' répu ', { forQuery: 'répu', response }).status).toBe('ready');
});

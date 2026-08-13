import { expect, test } from 'bun:test';
import type { DeparturesResponse } from '@via/contract';

import { departuresState } from './state';

const response: DeparturesResponse = {
  source: 'realtime',
  generatedAt: '2026-08-12T18:00:00+02:00',
  groups: [],
};

test('no completion yet is loading', () => {
  expect(departuresState('IDFM:71264').status).toBe('loading');
});

test("another station's answer does not paint under the new one", () => {
  const state = departuresState('IDFM:415852', { forStationId: 'IDFM:71264', response });

  expect(state.status).toBe('loading');
});

test('a completion without response is an error', () => {
  expect(departuresState('IDFM:71264', { forStationId: 'IDFM:71264' }).status).toBe('error');
});

test('a matching completion is ready with its response', () => {
  const state = departuresState('IDFM:71264', { forStationId: 'IDFM:71264', response });

  expect(state).toEqual({ status: 'ready', response });
});

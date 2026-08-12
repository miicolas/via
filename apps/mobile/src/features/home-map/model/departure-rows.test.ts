import type { NetworkRoute } from '@via/contract';
import { expect, test } from 'bun:test';

import { departureRows } from './departure-rows';

const line = (id: string): NetworkRoute => ({
  id,
  shortName: id,
  longName: `Ligne ${id}`,
  color: '#000000',
  textColor: '#FFFFFF',
  destinations: [],
  segments: [],
});

test('a line with no group gets one placeholder row', () => {
  const rows = departureRows([line('1')], []);

  expect(rows).toEqual([{ key: '1', route: line('1') }]);
});

test('a line splits into one row per destination', () => {
  const rows = departureRows(
    [line('1')],
    [
      { routeId: '1', destination: 'La Défense', departures: ['2026-08-12T10:00:00Z'] },
      { routeId: '1', destination: 'Château de Vincennes', departures: ['2026-08-12T10:02:00Z'] },
    ]
  );

  expect(rows.map((row) => row.destination)).toEqual(['La Défense', 'Château de Vincennes']);
  expect(rows.map((row) => row.key)).toEqual(['1 La Défense', '1 Château de Vincennes']);
});

test("another line's groups never leak into a route's rows", () => {
  const rows = departureRows(
    [line('1'), line('4')],
    [{ routeId: '4', destination: 'Bagneux', departures: ['2026-08-12T10:00:00Z'] }]
  );

  expect(rows.map((row) => [row.route.id, row.destination])).toEqual([
    ['1', undefined],
    ['4', 'Bagneux'],
  ]);
});

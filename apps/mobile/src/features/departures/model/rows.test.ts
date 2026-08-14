import type { RouteBadge } from '@via/contract';
import { expect, test } from 'bun:test';

import { departureRows } from './rows';

const now = new Date('2026-08-12T10:00:00Z');

const badge = (id: string): RouteBadge => ({
  id,
  shortName: id,
  color: '#000000',
  textColor: '#FFFFFF',
  mode: 'metro',
});

test('no announced departures yields no rows', () => {
  expect(departureRows([], now)).toEqual([]);
});

test('an empty destination group is omitted', () => {
  const rows = departureRows(
    [{ route: badge('1'), destination: 'La Défense', departures: [] }],
    now
  );

  expect(rows).toEqual([]);
});

test('a line groups every announced direction into one row', () => {
  const rows = departureRows(
    [
      { route: badge('1'), destination: 'La Défense', departures: ['2026-08-12T10:00:00Z'] },
      {
        route: badge('1'),
        destination: 'Château de Vincennes',
        departures: ['2026-08-12T10:02:00Z'],
      },
    ],
    now
  );

  expect(rows).toHaveLength(1);
  expect(rows[0]?.key).toBe('1');
  expect(rows[0]?.route).toEqual(badge('1'));
  expect(rows[0]?.directions.map((direction) => direction.destination)).toEqual([
    'La Défense',
    'Château de Vincennes',
  ]);
});

test('a group whose last announced departure has expired is omitted', () => {
  const rows = departureRows(
    [{ route: badge('1'), destination: 'La Défense', departures: ['2026-08-12T09:58:00Z'] }],
    now
  );

  expect(rows).toEqual([]);
});

test('rows follow the shared line order, not payload order', () => {
  const rows = departureRows(
    [
      { route: badge('4'), destination: 'Bagneux', departures: ['2026-08-12T10:00:00Z'] },
      { route: badge('1'), destination: 'La Défense', departures: ['2026-08-12T10:01:00Z'] },
    ],
    now
  );

  expect(rows.map((row) => row.route.id)).toEqual(['1', '4']);
});

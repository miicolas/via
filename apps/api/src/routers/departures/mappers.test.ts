import type { RouteBadge } from '@via/contract';
import { expect, test } from 'bun:test';

import { toDepartureGroups } from './mappers';
import type { NormalizedVisit } from './prim/parse';

const now = new Date('2026-08-12T18:00:00+02:00');

const at = (minutes: number) =>
  new Date(now.getTime() + minutes * 60_000).toISOString();

const visit = (routeId: string, destination: string, minutes: number): NormalizedVisit => ({
  routeId,
  destination,
  expectedAt: at(minutes),
});

const badge = (id: string): RouteBadge => ({
  id,
  shortName: '1',
  mode: 'metro',
  color: '#FFCD00',
  textColor: '#000000',
});

test('visits bucket by line and destination, soonest first', () => {
  const groups = toDepartureGroups(
    [
      visit('IDFM:C01371', 'La Défense', 7),
      visit('IDFM:C01371', 'Château de Vincennes', 2),
      visit('IDFM:C01371', 'La Défense', 3),
    ],
    [badge('IDFM:C01371')],
    now
  );

  expect(groups).toHaveLength(2);
  expect(groups.map((group) => group.destination)).toEqual([
    'Château de Vincennes',
    'La Défense',
  ]);
  expect(groups[1].departures).toEqual([at(3), at(7)]);
});

test("other lines' visits in the same payload are filtered out", () => {
  const groups = toDepartureGroups(
    [visit('IDFM:C01742', 'Saint-Rémy-lès-Chevreuse', 4), visit('IDFM:C01371', 'La Défense', 5)],
    [badge('IDFM:C01371')],
    now
  );

  expect(groups.map((group) => group.route.id)).toEqual(['IDFM:C01371']);
});

test('what already left is dropped and each group caps at four', () => {
  const groups = toDepartureGroups(
    [-3, 1, 4, 7, 10, 13].map((minutes) => visit('IDFM:C01371', 'La Défense', minutes)),
    [badge('IDFM:C01371')],
    now
  );

  expect(groups[0].departures).toEqual([at(1), at(4), at(7), at(10)]);
});

test("each group carries its line's badge", () => {
  const groups = toDepartureGroups(
    [visit('IDFM:C01371', 'La Défense', 5)],
    [badge('IDFM:C01371')],
    now
  );

  expect(groups[0].route).toEqual(badge('IDFM:C01371'));
});

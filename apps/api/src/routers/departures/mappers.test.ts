import { SERVICE_DAY_DEPARTURES_PER_GROUP, type DepartureGroup, type RouteBadge } from '@via/contract';
import { expect, test } from 'bun:test';

import { toDepartureGroups } from './mappers';
import type { NormalizedVisit } from './prim/parse';

const now = new Date('2026-08-12T18:00:00+02:00');

const at = (minutes: number) =>
  Math.floor((now.getTime() + minutes * 60_000) / 1_000);

const isoAt = (minutes: number) => new Date(at(minutes) * 1_000).toISOString();

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
  expect(groups[1].departures).toEqual([isoAt(3), isoAt(7)]);
  expect(groups[1].departureItems.map((item) => item.status)).toEqual(['no_report', 'no_report']);
});

test('keeps PRIM default onTime neutral without a delay baseline', () => {
  const groups = toDepartureGroups(
    [
      {
        routeId: 'IDFM:C01371',
        destination: 'La Défense',
        expectedAt: at(5),
        providerStatus: 'on_time',
      },
    ],
    [badge('IDFM:C01371')],
    now
  );

  expect(groups[0]?.departureItems[0]).toMatchObject({ status: 'no_report' });
  expect(groups[0]?.departureItems[0]).not.toHaveProperty('delaySeconds');
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
    [-3, 13, 1, 10, 4, 7].map((minutes) => visit('IDFM:C01371', 'La Défense', minutes)),
    [badge('IDFM:C01371')],
    now
  );

  expect(groups[0].departures).toEqual([isoAt(1), isoAt(4), isoAt(7), isoAt(10)]);
  expect(groups[0].departureItems).toHaveLength(4);
});

test("each group carries its line's badge", () => {
  const groups = toDepartureGroups(
    [visit('IDFM:C01371', 'La Défense', 5)],
    [badge('IDFM:C01371')],
    now
  );

  expect(groups[0].route).toEqual(badge('IDFM:C01371'));
});

test('computed timing wins over a contradictory provider timing status', () => {
  const groups = toDepartureGroups(
    [
      {
        routeId: 'IDFM:C01371',
        destination: 'La Défense',
        scheduledAt: at(5),
        expectedAt: at(8),
        providerStatus: 'on_time',
      },
    ],
    [badge('IDFM:C01371')],
    now,
    'IDFM:71264'
  );

  expect(groups[0].departureItems[0]).toMatchObject({
    status: 'delayed',
    delaySeconds: 180,
  });
});

test('cancellations without a timestamp remain visible', () => {
  const groups = toDepartureGroups(
    [
      {
        routeId: 'IDFM:C01371',
        destination: 'La Défense',
        providerStatus: 'cancelled',
      },
    ],
    [badge('IDFM:C01371')],
    now,
    'IDFM:71264'
  );

  expect(groups[0].departureItems).toHaveLength(1);
  expect(groups[0].departureItems[0]).toMatchObject({ status: 'cancelled' });
  expect(groups[0].departures).toEqual([]);
});

test('arrived and departed passages are hidden from the future board', () => {
  const groups = toDepartureGroups(
    [
      {
        routeId: 'IDFM:C01371',
        destination: 'La Défense',
        expectedAt: at(5),
        providerStatus: 'arrived',
      },
      {
        routeId: 'IDFM:C01371',
        destination: 'La Défense',
        expectedAt: at(6),
        providerStatus: 'departed',
      },
    ],
    [badge('IDFM:C01371')],
    now
  );

  expect(groups).toEqual([]);
});

test('matches a realtime estimate to the GTFS baseline and computes the delay', () => {
  const route = badge('IDFM:C01371');
  const scheduledAt = isoAt(5);
  const theoretical: DepartureGroup[] = [
    {
      route,
      destination: 'La Défense',
      departures: [scheduledAt],
      departureItems: [
        {
          id: 'scheduled',
          scheduledAt,
          status: 'scheduled',
        },
      ],
    },
  ];

  const groups = toDepartureGroups(
    [
      {
        routeId: route.id,
        destination: 'La Défense',
        expectedAt: at(8),
      },
    ],
    [route],
    now,
    'IDFM:71264',
    theoretical
  );

  expect(groups[0]?.departureItems[0]).toMatchObject({
    scheduledAt,
    expectedAt: isoAt(8),
    status: 'delayed',
    delaySeconds: 180,
  });
});

test('a service-day board appends scheduled departures not announced by realtime', () => {
  const route = badge('IDFM:C01371');
  const theoretical: DepartureGroup[] = [
    {
      route,
      destination: 'La Défense',
      departures: [isoAt(5), isoAt(30)],
      departureItems: [
        {
          id: 'scheduled-first',
          scheduledAt: isoAt(5),
          status: 'scheduled',
        },
        {
          id: 'scheduled-rest',
          scheduledAt: isoAt(30),
          status: 'scheduled',
        },
      ],
    },
  ];

  const groups = toDepartureGroups(
    [visit(route.id, 'La Défense', 5)],
    [route],
    now,
    'IDFM:71264',
    theoretical,
    {
      includeTheoreticalRemainder: true,
      maxDeparturesPerGroup: SERVICE_DAY_DEPARTURES_PER_GROUP,
    }
  );

  expect(groups[0]?.departures).toEqual([isoAt(5), isoAt(30)]);
  expect(groups[0]?.departureItems).toHaveLength(2);
  expect(groups[0]?.departureItems[1]).toMatchObject({
    id: 'scheduled-rest',
    status: 'scheduled',
  });
});

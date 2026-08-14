import { expect, test } from 'bun:test';

import type { RouteBadge } from '@via/contract';

import { nextTheoreticalDepartures, type TheoreticalDepartureRow } from './next-departures';

const badge = (id: string): RouteBadge => ({
  id,
  shortName: '1',
  mode: 'metro',
  color: '#FFCD00',
  textColor: '#000000',
});

const row = (
  routeId: string,
  headsign: string,
  departureSeconds: number
): TheoreticalDepartureRow => ({ routeId, headsign, departureSeconds });

/** Answers per service date, so a test can stage yesterday and today apart. */
const loaderOf = (byDate: Record<string, TheoreticalDepartureRow[]>) =>
  async (serviceDate: string, afterSeconds: number) =>
    (byDate[serviceDate] ?? []).filter((entry) => entry.departureSeconds > afterSeconds);

test('departures group by line and headsign, soonest first', async () => {
  const groups = await nextTheoreticalDepartures(
    new Date('2026-08-12T16:00:00Z'), // 18:00 Paris
    [badge('IDFM:C01371')],
    loaderOf({
      '2026-08-12': [
        row('IDFM:C01371', 'La Défense', 18 * 3600 + 240),
        row('IDFM:C01371', 'Château de Vincennes', 18 * 3600 + 120),
        row('IDFM:C01371', 'La Défense', 18 * 3600 + 480),
      ],
    })
  );

  expect(groups.map((group) => group.destination)).toEqual([
    'Château de Vincennes',
    'La Défense',
  ]);
  expect(groups[1].departures).toEqual([
    '2026-08-12T16:04:00.000Z',
    '2026-08-12T16:08:00.000Z',
  ]);
});

test("just past midnight, yesterday's service still supplies the trains", async () => {
  const groups = await nextTheoreticalDepartures(
    new Date('2026-08-12T22:30:00Z'), // 00:30 Paris on the 13th
    [badge('IDFM:C01371')],
    loaderOf({
      // "24:45" of the 12th — the night service, recorded past 24 h.
      '2026-08-12': [row('IDFM:C01371', 'La Défense', 24 * 3600 + 45 * 60)],
      '2026-08-13': [row('IDFM:C01371', 'La Défense', 5 * 3600 + 30 * 60)],
    })
  );

  expect(groups[0].departures).toEqual([
    '2026-08-12T22:45:00.000Z', // 00:45 Paris, from yesterday's service
    '2026-08-13T03:30:00.000Z', // 05:30 Paris, today's first train
  ]);
});

test("lines the station does not serve are dropped", async () => {
  const groups = await nextTheoreticalDepartures(
    new Date('2026-08-12T16:00:00Z'),
    [badge('IDFM:C01371')],
    loaderOf({
      '2026-08-12': [
        row('IDFM:C01381', 'Châtelet', 18 * 3600 + 60),
        row('IDFM:C01371', 'La Défense', 18 * 3600 + 120),
      ],
    })
  );

  expect(groups.map((group) => group.route.id)).toEqual(['IDFM:C01371']);
});

test('each group caps at four departures', async () => {
  const groups = await nextTheoreticalDepartures(
    new Date('2026-08-12T16:00:00Z'),
    [badge('IDFM:C01371')],
    loaderOf({
      '2026-08-12': [2, 5, 8, 11, 14, 17].map((minutes) =>
        row('IDFM:C01371', 'La Défense', 18 * 3600 + minutes * 60)
      ),
    })
  );

  expect(groups[0].departures).toHaveLength(4);
});

test('nothing scheduled yields no groups', async () => {
  const groups = await nextTheoreticalDepartures(
    new Date('2026-08-12T16:00:00Z'),
    [badge('IDFM:C01371')],
    loaderOf({})
  );

  expect(groups).toEqual([]);
});

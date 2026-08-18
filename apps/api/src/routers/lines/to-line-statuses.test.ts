import { expect, test } from 'bun:test';

import type { DisruptionsSnapshot } from './disruptions/snapshot';
import type { LineRow } from './queries';
import { toLineStatuses } from './to-line-statuses';

const now = new Date('2026-08-18T12:00:00+02:00');
const nowSeconds = Math.floor(now.getTime() / 1_000);

function line(overrides: Partial<LineRow>): LineRow {
  return {
    id: 'IDFM:C01371',
    shortName: '1',
    longName: 'La Défense - Château de Vincennes',
    routeType: 1,
    color: 'FFCD00',
    textColor: '000000',
    ...overrides,
  };
}

const snapshot: DisruptionsSnapshot = {
  disruptions: [
    {
      id: 'd-block',
      severity: 'suspended',
      title: 'Trafic interrompu',
      routeIds: ['IDFM:C01371'],
      periods: [{ beginsAt: nowSeconds - 3_600, endsAt: nowSeconds + 3_600 }],
      impactedSections: [],
    },
  ],
  fetchedAt: nowSeconds - 60,
};

test('canonical order sorts by mode then natural code order', () => {
  const rows = [
    line({ id: 'IDFM:C01384', shortName: '14' }),
    line({ id: 'IDFM:C01742', shortName: 'A', routeType: 2 }),
    line({ id: 'IDFM:C01371', shortName: '1' }),
    line({ id: 'IDFM:C01389', shortName: '2' }),
    line({ id: 'IDFM:C01390', shortName: 'T3a', routeType: 0 }),
    line({ id: 'IDFM:C01739', shortName: 'L', routeType: 2 }),
  ];

  const { lines } = toLineStatuses(rows, snapshot, now);

  expect(lines.map((entry) => entry.route.shortName)).toEqual(['1', '2', '14', 'A', 'L', 'T3a']);
});

test('a live snapshot marks the disrupted line and stamps fetchedAt', () => {
  const response = toLineStatuses([line({})], snapshot, now);

  expect(response.source).toBe('live');
  expect(response.fetchedAt).toBe(new Date((nowSeconds - 60) * 1_000).toISOString());
  expect(response.lines[0]).toMatchObject({
    condition: 'suspended',
    summary: 'Trafic interrompu',
    activeCount: 1,
  });
  expect(response.lines[0]?.route).toEqual({
    id: 'IDFM:C01371',
    shortName: '1',
    mode: 'metro',
    color: '#FFCD00',
    textColor: '#000000',
  });
});

test('a missing snapshot degrades to unavailable, never to falsely healthy', () => {
  const response = toLineStatuses([line({})], null, now);

  expect(response.source).toBe('unavailable');
  expect(response.fetchedAt).toBeUndefined();
  expect(response.lines[0]).toEqual({
    route: expect.objectContaining({ id: 'IDFM:C01371' }),
    condition: 'normal',
    activeCount: 0,
  });
});

test('given order survives untouched for search relevance', () => {
  const rows = [
    line({ id: 'IDFM:C00384', shortName: '380', routeType: 3 }),
    line({ id: 'IDFM:C00038', shortName: '38', routeType: 3 }),
  ];

  const { lines } = toLineStatuses(rows, snapshot, now, 'given');

  expect(lines.map((entry) => entry.route.shortName)).toEqual(['380', '38']);
});

import type { Journey, JourneySection, JourneyStop } from '@via/contract';
import { expect, test } from 'bun:test';

import { intermediateStops } from '@/features/journey/model/intermediate-stops';
import { journeyTimelineRows } from '@/features/journey/model/timeline-rows';

const coordinate = { latitude: 48.86, longitude: 2.35 };

function stop(name: string): JourneyStop {
  return { id: `stop-${name}`, name, coordinate };
}

function section(
  type: JourneySection['type'],
  minutes: number,
  overrides: Partial<JourneySection> = {}
): JourneySection {
  return {
    type,
    durationSeconds: minutes * 60,
    from: { name: `${type}-from`, coordinate },
    to: { name: `${type}-to`, coordinate },
    geometry: [],
    stops: [],
    ...overrides,
  };
}

function transit(minutes: number, shortName: string, overrides: Partial<JourneySection> = {}) {
  return section('transit', minutes, {
    route: {
      id: `line-${shortName}`,
      shortName,
      longName: `Ligne ${shortName}`,
      mode: 'metro',
      color: '#8D5E2A',
      textColor: '#FFFFFF',
    },
    ...overrides,
  });
}

function journey(sections: JourneySection[], warnings: string[] = []): Journey {
  return {
    id: 'journey-1',
    qualifier: 'recommended',
    durationSeconds: sections.reduce((sum, item) => sum + item.durationSeconds, 0),
    walkingDurationSeconds: 0,
    transferCount: 1,
    departureAt: '2026-08-13T20:42:00+02:00',
    arrivalAt: '2026-08-13T21:41:00+02:00',
    status: 'normal',
    warnings,
    sections,
  };
}

test('walk, ride, connection, ride maps to one row each', () => {
  const rows = journeyTimelineRows(
    journey([
      section('walk', 6),
      transit(15, 'A'),
      section('transfer', 4),
      transit(25, '1'),
      section('walk', 3),
    ])
  );

  expect(rows.map((row) => row.kind)).toEqual(['walk', 'transit', 'transfer', 'transit', 'walk']);
});

test('consecutive transfer and wait collapse into one connection with summed minutes', () => {
  const rows = journeyTimelineRows(
    journey([transit(15, 'A'), section('transfer', 3), section('wait', 4), transit(25, '1')])
  );

  expect(rows).toHaveLength(3);
  expect(rows[1]).toMatchObject({ kind: 'transfer', minutes: 7 });
});

test('a connection names the stop you leave and the line you board next', () => {
  const rows = journeyTimelineRows(
    journey([
      transit(15, 'A', { to: { name: 'La Défense', coordinate } }),
      section('transfer', 4, { from: { name: 'La Défense', coordinate } }),
      section('walk', 2),
      transit(25, '1'),
    ])
  );

  expect(rows[1]).toMatchObject({
    kind: 'transfer',
    stopName: 'La Défense',
    nextRoute: expect.objectContaining({ shortName: '1' }),
  });
});

test('a wait before ever boarding is dropped, not shown as a connection', () => {
  const rows = journeyTimelineRows(
    journey([section('walk', 6), section('wait', 5), transit(15, 'A')])
  );

  expect(rows.map((row) => row.kind)).toEqual(['walk', 'transit']);
});

test('a trailing connection after the last ride keeps the stop but has no next line', () => {
  const rows = journeyTimelineRows(journey([transit(15, 'A'), section('wait', 2)]));

  expect(rows[1]).toMatchObject({ kind: 'transfer', nextRoute: undefined });
});

test('the journey warning lands on the first transit row only', () => {
  const rows = journeyTimelineRows(
    journey([transit(15, 'A'), section('transfer', 4), transit(25, '1')], ['Interrompu'])
  );

  expect(rows[0]).toMatchObject({ kind: 'transit', warning: 'Interrompu' });
  expect(rows[2]).toMatchObject({ kind: 'transit', warning: undefined });
});

test('a walking-only journey is a single walk row', () => {
  const rows = journeyTimelineRows(journey([section('walk', 12)]));

  expect(rows).toEqual([{ kind: 'walk', minutes: 12, targetName: 'walk-to' }]);
});

test('stop count excludes the boarding stop, and hides when the feed sent too few', () => {
  const stops = [stop('a'), stop('b'), stop('c'), stop('d')];
  const [ridden] = journeyTimelineRows(journey([transit(15, 'A', { stops })]));
  const [bare] = journeyTimelineRows(journey([transit(15, 'A', { stops: [stop('a')] })]));

  expect(ridden).toMatchObject({ stopCount: 3 });
  expect(bare).toMatchObject({ stopCount: undefined });
});

test('intermediate stops trim boarding and alighting', () => {
  const stops = [stop('a'), stop('b'), stop('c'), stop('d')];

  expect(intermediateStops(transit(15, 'A', { stops })).map((item) => item.name)).toEqual([
    'b',
    'c',
  ]);
  expect(intermediateStops(transit(15, 'A', { stops: [stop('a'), stop('d')] }))).toEqual([]);
});

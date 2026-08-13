import type { Journey, JourneySection } from '@via/contract';
import { expect, test } from 'bun:test';

import { journeySegments } from '@/features/journey/model/segments';

const coordinate = { latitude: 48.86, longitude: 2.35 };

function section(
  type: JourneySection['type'],
  minutes: number,
  shortName?: string
): JourneySection {
  return {
    type,
    durationSeconds: minutes * 60,
    from: { name: `${type}-from-${minutes}`, coordinate },
    to: { name: `${type}-to-${minutes}`, coordinate },
    geometry: [],
    stops: [],
    route: shortName
      ? {
          id: `line-${shortName}`,
          shortName,
          longName: `Ligne ${shortName}`,
          mode: 'metro',
          color: '#8D5E2A',
          textColor: '#FFFFFF',
        }
      : undefined,
  };
}

function journey(sections: JourneySection[]): Journey {
  return {
    id: 'journey-1',
    qualifier: 'recommended',
    durationSeconds: sections.reduce((sum, item) => sum + item.durationSeconds, 0),
    walkingDurationSeconds: 0,
    transferCount: 1,
    departureAt: '2026-08-13T20:42:00+02:00',
    arrivalAt: '2026-08-13T21:41:00+02:00',
    status: 'normal',
    warnings: [],
    sections,
  };
}

test('a journey with a connection keeps every leg', () => {
  const segments = journeySegments(
    journey([
      section('walk', 2),
      section('transit', 5, '1'),
      section('transfer', 3),
      section('wait', 4),
      section('transit', 21, '13'),
      section('walk', 2),
    ])
  );

  expect(segments.map((segment) => segment.kind)).toEqual([
    'walk',
    'transit',
    'walk',
    'wait',
    'transit',
    'walk',
  ]);
  expect(segments.map((segment) => segment.route?.shortName)).toEqual([
    undefined,
    '1',
    undefined,
    undefined,
    '13',
    undefined,
  ]);
});

test('segments cover the whole duration', () => {
  const sections = [section('walk', 2), section('wait', 45), section('transit', 5, '1')];
  const covered = journeySegments(journey(sections)).reduce(
    (sum, segment) => sum + segment.minutes,
    0
  );

  expect(covered).toBe(52);
});

test('consecutive sections of one kind merge instead of splintering', () => {
  const segments = journeySegments(
    journey([section('walk', 2), section('transfer', 3), section('transit', 5, '1')])
  );

  expect(segments).toHaveLength(2);
  expect(segments[0]).toMatchObject({ kind: 'walk', minutes: 5 });
});

test('a ride with no line reads as time waited, never dropped', () => {
  const segments = journeySegments(journey([section('transit', 8)]));

  expect(segments).toEqual([expect.objectContaining({ kind: 'wait', minutes: 8 })]);
});

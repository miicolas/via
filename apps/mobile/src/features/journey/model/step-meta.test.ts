import { expect, test } from 'bun:test';

import { transitStepMeta } from '@/features/journey/model/step-meta';
import { formatTime } from '@/lib/format-time';

const departureAt = '2026-08-13T10:06:00+02:00';
const clock = formatTime(departureAt);

test('a realtime leg spells out time, platform, duration and stops', () => {
  expect(
    transitStepMeta({
      departureAt,
      minutes: 15,
      platform: '2',
      stopCount: 6,
    })
  ).toBe(`${clock} · voie 2 · 15 min · 6 arrêts`);
});

test('a theoretical leg without platform or stops still reads cleanly', () => {
  expect(transitStepMeta({ departureAt, minutes: 15 })).toBe(`${clock} · 15 min`);
});

test('duration is the only guaranteed part', () => {
  expect(transitStepMeta({ minutes: 4 })).toBe('4 min');
});

test('a single stop is written in the singular', () => {
  expect(transitStepMeta({ minutes: 3, stopCount: 1 })).toBe('3 min · 1 arrêt');
});

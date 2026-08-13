import { expect, test } from 'bun:test';

import type { JourneySegment } from '@/features/journey/model/segments';
import { stripDensity } from '@/features/journey/model/strip-density';

function segment(kind: JourneySegment['kind'], minutes: number): JourneySegment {
  return { key: `${kind}-${minutes}`, kind, minutes };
}

test('a trip with one connection spells everything out', () => {
  const segments = [
    segment('walk', 3),
    segment('transit', 6),
    segment('transit', 5),
    segment('walk', 2),
  ];

  expect(stripDensity(segments)).toBe('full');
});

test('a third line costs the row its wording, a fourth its walks', () => {
  const three = [segment('transit', 6), segment('transit', 5), segment('transit', 9)];
  expect(stripDensity(three)).toBe('compact');

  expect(stripDensity([...three, segment('transit', 4)])).toBe('minimal');
});

test('walks alone never crowd the strip', () => {
  expect(stripDensity([segment('walk', 18)])).toBe('full');
});

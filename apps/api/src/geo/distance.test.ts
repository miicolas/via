import { expect, test } from 'bun:test';

import { haversineMeters } from './distance';

const republique = { latitude: 48.8676, longitude: 2.3641 };
const rivoli12 = { latitude: 48.8556, longitude: 2.35995 };

test('République to 12 Rue de Rivoli is about 1.4 km', () => {
  const distance = haversineMeters(republique, rivoli12);

  expect(distance).toBeGreaterThan(1_300);
  expect(distance).toBeLessThan(1_450);
});

test('distance is symmetric and zero at the same point', () => {
  expect(haversineMeters(republique, rivoli12)).toBeCloseTo(
    haversineMeters(rivoli12, republique)
  );
  expect(haversineMeters(republique, republique)).toBe(0);
});

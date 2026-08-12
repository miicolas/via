import { describe, expect, test } from 'bun:test';

import { lineLengthMeters } from './line-length';

describe('lineLengthMeters', () => {
  test('sums the great-circle distance along the line', () => {
    // Roughly 1° of longitude at the equator, twice: ~222 km.
    const length = lineLengthMeters([
      { latitude: 0, longitude: 0 },
      { latitude: 0, longitude: 1 },
      { latitude: 0, longitude: 2 },
    ]);

    expect(length).toBeGreaterThan(220_000);
    expect(length).toBeLessThan(225_000);
  });

  test('is zero for a point or an empty line', () => {
    expect(lineLengthMeters([])).toBe(0);
    expect(lineLengthMeters([{ latitude: 48.86, longitude: 2.35 }])).toBe(0);
  });
});

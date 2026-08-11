import { describe, expect, test } from 'bun:test';

import { toCoordinates } from './coordinates';

describe('toCoordinates', () => {
  test('flips GeoJSON [longitude, latitude] into named map coordinates', () => {
    const geoJson = '{"type":"LineString","coordinates":[[2.3364,48.8606],[2.3522,48.8566]]}';

    expect(toCoordinates(geoJson)).toEqual([
      { latitude: 48.8606, longitude: 2.3364 },
      { latitude: 48.8566, longitude: 2.3522 },
    ]);
  });

  /**
   * The regression this guards: latitude is bounded to ±90 and longitude to ±180,
   * so a swapped pair stays *valid* for Paris and only shows up as a map drawn in
   * the wrong hemisphere.
   */
  test('keeps Paris in Paris', () => {
    const [paris] = toCoordinates('{"type":"LineString","coordinates":[[2.3522,48.8566]]}');

    expect(paris.latitude).toBeGreaterThan(48);
    expect(paris.longitude).toBeLessThan(3);
  });

  test('handles an empty line', () => {
    expect(toCoordinates('{"type":"LineString","coordinates":[]}')).toEqual([]);
  });
});

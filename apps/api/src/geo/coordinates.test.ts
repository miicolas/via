import { describe, expect, test } from 'bun:test';

import { toLineStrings } from './coordinates';

describe('toLineStrings', () => {
  test('flips GeoJSON [longitude, latitude] into named map coordinates', () => {
    const geoJson = '{"type":"LineString","coordinates":[[2.3364,48.8606],[2.3522,48.8566]]}';

    expect(toLineStrings(geoJson)).toEqual([
      [
        { latitude: 48.8606, longitude: 2.3364 },
        { latitude: 48.8566, longitude: 2.3522 },
      ],
    ]);
  });

  /**
   * The regression this guards: latitude is bounded to ±90 and longitude to ±180,
   * so a swapped pair stays *valid* for Paris and only shows up as a map drawn in
   * the wrong hemisphere.
   */
  test('keeps Paris in Paris', () => {
    const [[paris]] = toLineStrings('{"type":"LineString","coordinates":[[2.3522,48.8566]]}');

    expect(paris.latitude).toBeGreaterThan(48);
    expect(paris.longitude).toBeLessThan(3);
  });

  test('splits a MultiLineString into one polyline per part', () => {
    const geoJson =
      '{"type":"MultiLineString","coordinates":[[[2.33,48.86],[2.34,48.86]],[[2.35,48.85],[2.36,48.85]]]}';

    expect(toLineStrings(geoJson)).toEqual([
      [
        { latitude: 48.86, longitude: 2.33 },
        { latitude: 48.86, longitude: 2.34 },
      ],
      [
        { latitude: 48.85, longitude: 2.35 },
        { latitude: 48.85, longitude: 2.36 },
      ],
    ]);
  });

  test('flattens a GeometryCollection', () => {
    const geoJson =
      '{"type":"GeometryCollection","geometries":[{"type":"LineString","coordinates":[[2.33,48.86],[2.34,48.86]]}]}';

    expect(toLineStrings(geoJson)).toEqual([
      [
        { latitude: 48.86, longitude: 2.33 },
        { latitude: 48.86, longitude: 2.34 },
      ],
    ]);
  });

  /** What PostGIS returns for a pattern whose track deduplicated into nothing. */
  test('returns no lines for the empty geometries', () => {
    expect(toLineStrings('{"type":"LineString","coordinates":[]}')).toEqual([]);
    expect(toLineStrings('{"type":"MultiLineString","coordinates":[]}')).toEqual([]);
    expect(toLineStrings('{"type":"GeometryCollection","geometries":[]}')).toEqual([]);
  });
});

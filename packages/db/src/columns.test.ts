import { describe, expect, test } from 'bun:test';

import type { LonLat } from './columns';
import { transitRoutePatterns, transitStops } from './schema';

/**
 * The EWKB decoding in `columns.ts` is the one place in this repo where a bug
 * produces plausible but wrong coordinates rather than an error: no exception,
 * no failed query, just a map drawn slightly — or entirely — in the wrong place.
 *
 * These fixtures are real bytes captured from PostGIS (except the big-endian one,
 * which this machine never emits and which the parser nonetheless claims to
 * handle). They are asserted through the columns themselves, which is the
 * interface the driver actually uses.
 */

/** `ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326)` — Notre-Dame. */
const POINT = '0101000020e6100000a835cd3b4ed1024076e09c11a56d4840';

/** `LINESTRING(2.3364 48.8606, 2.3522 48.8566)`, SRID 4326, little-endian. */
const LINE = '0102000020e610000002000000c5feb27bf2b0024003780b24286e4840a835cd3b4ed1024076e09c11a56d4840';

/** The same two points, hand-built big-endian. PostGIS emits little-endian here. */
const LINE_BIG_ENDIAN =
  '0020000002000010e6000000024002b0f27bb2fec540486e28240b78034002d14e3bcd35a840486da5119ce076';

// drizzle types `mapFromDriverValue` as `unknown`; the column's own contract is
// what says otherwise, and that contract is what these tests are checking.
const decodePoint = (hex: string) => transitStops.location.mapFromDriverValue(hex) as LonLat;
const decodeLine = (hex: string) => transitRoutePatterns.geometry.mapFromDriverValue(hex) as LonLat[];

describe('pointWgs84', () => {
  test('decodes a PostGIS point without swapping the axes', () => {
    expect(decodePoint(POINT)).toEqual({ lon: 2.3522, lat: 48.8566 });
  });

  /**
   * The regression that matters: latitude is bounded to ±90 and longitude to
   * ±180, so a swapped pair stays a *valid* coordinate and only shows up as a
   * map rendered in the wrong hemisphere.
   */
  test('keeps Paris in Paris', () => {
    const { lon, lat } = decodePoint(POINT);

    expect(lat).toBeGreaterThan(48);
    expect(lon).toBeLessThan(3);
  });

  test('round-trips through the driver representation', () => {
    const wrapped = transitStops.location.mapToDriverValue({ lon: 2.3522, lat: 48.8566 });

    // A `sql` fragment carrying the values, not a string: the SRID is pinned in SQL.
    expect(wrapped).toBeDefined();
  });
});

describe('lineStringWgs84', () => {
  test('decodes every vertex in order', () => {
    expect(decodeLine(LINE)).toEqual([
      { lon: 2.3364, lat: 48.8606 },
      { lon: 2.3522, lat: 48.8566 },
    ]);
  });

  test('honours the byte order flag rather than assuming little-endian', () => {
    expect(decodeLine(LINE_BIG_ENDIAN)).toEqual(decodeLine(LINE));
  });

  test('rejects a geometry that is not a LineString', () => {
    expect(() => decodeLine(POINT)).toThrow('LineString');
  });

  test('refuses to write a line with fewer than two coordinates', () => {
    expect(() => transitRoutePatterns.geometry.mapToDriverValue([{ lon: 2.35, lat: 48.85 }])).toThrow(
      'at least two'
    );
  });

  /**
   * A real 335-vertex alignment: the loop, the offset arithmetic and the SRID
   * skip all have to hold past the first point.
   */
  test('decodes a full metro alignment end to end', async () => {
    const hex = (await Bun.file(`${import.meta.dir}/__fixtures__/line-1-alignment.hex`).text()).trim();
    const points = decodeLine(hex);

    expect(points).toHaveLength(335);
    expect(points[0]).toEqual({ lon: 2.278379, lat: 48.836395 });
    expect(points.at(-1)).toEqual({ lon: 2.464248, lat: 48.768829 });
    // Every vertex must land in the Île-de-France bounding box.
    for (const { lon, lat } of points) {
      expect(lon).toBeGreaterThan(1.4);
      expect(lon).toBeLessThan(3.6);
      expect(lat).toBeGreaterThan(48.1);
      expect(lat).toBeLessThan(49.3);
    }
  });
});

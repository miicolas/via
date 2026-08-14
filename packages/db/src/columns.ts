import { sql } from 'drizzle-orm';
import { customType } from 'drizzle-orm/pg-core';
import { parseEWKB } from 'drizzle-orm/pg-core/columns/postgis_extension/utils';

export type LonLat = { lon: number; lat: number };

function parseLineStringEWKB(hex: string): LonLat[] {
  const bytes = Uint8Array.fromHex(hex);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const littleEndian = view.getUint8(0) === 1;
  let offset = 1;
  const geometryType = view.getUint32(offset, littleEndian);
  offset += 4;

  if (geometryType & 0x20000000) offset += 4;
  if ((geometryType & 0xffff) !== 2) {
    throw new Error('Expected a LineString geometry');
  }

  const pointCount = view.getUint32(offset, littleEndian);
  offset += 4;
  const points: LonLat[] = [];

  for (let index = 0; index < pointCount; index += 1) {
    const lon = view.getFloat64(offset, littleEndian);
    offset += 8;
    const lat = view.getFloat64(offset, littleEndian);
    offset += 8;
    points.push({ lon, lat });
  }

  return points;
}

/**
 * A WGS84 point column — `geometry(Point,4326)`.
 *
 * drizzle-orm 0.45's built-in `geometry()` accepts an `srid` option but drops
 * it on the floor: it emits `geometry(point)` and inserts SRID-0 WKT. For a
 * geospatial app that's a silent correctness hole (nothing stops a row from
 * landing in another coordinate system), so the column is declared here
 * instead, with the SRID pinned in both the DDL and every insert.
 */
export const pointWgs84 = customType<{
  data: LonLat;
  driverData: string;
}>({
  dataType() {
    return 'geometry(Point,4326)';
  },
  toDriver(value) {
    return sql`ST_SetSRID(ST_MakePoint(${value.lon}, ${value.lat}), 4326)`;
  },
  fromDriver(value) {
    // The driver hands back EWKB hex; reuse drizzle's own parser rather than
    // rolling a second one.
    const [lon, lat] = parseEWKB(value);
    return { lon, lat };
  },
});

/**
 * A WGS84 multi-track geometry — `geometry(MultiLineString,4326)`.
 *
 * Written and read exclusively by SQL (`ST_AsGeoJSON` on the way out), so the
 * driver value stays an opaque EWKB hex string: parsing it in JS would add a
 * decoder with no consumer.
 */
export const multiLineStringWgs84 = customType<{
  data: string;
  driverData: string;
}>({
  dataType() {
    return 'geometry(MultiLineString,4326)';
  },
});

/** A WGS84 transit alignment — `geometry(LineString,4326)`. */
export const lineStringWgs84 = customType<{
  data: LonLat[];
  driverData: string;
}>({
  dataType() {
    return 'geometry(LineString,4326)';
  },
  toDriver(value) {
    if (value.length < 2) {
      throw new Error('A LineString requires at least two coordinates');
    }

    const wkt = `LINESTRING(${value.map(({ lon, lat }) => `${lon} ${lat}`).join(',')})`;
    return sql`ST_GeomFromText(${wkt}, 4326)`;
  },
  fromDriver(value) {
    return parseLineStringEWKB(value);
  },
});

/**
 * A WGS84 position in the shape map clients consume.
 *
 * Declared here rather than imported from `@via/contract` on purpose: this module
 * is a geometry primitive and must not depend on the API's wire contract. That
 * the two coincide is checked where it matters, in the mapper.
 */
type Coordinate = {
  latitude: number;
  longitude: number;
};

type GeoJsonGeometry =
  | { type: 'LineString'; coordinates: [number, number][] }
  | { type: 'MultiLineString'; coordinates: [number, number][][] }
  | { type: 'GeometryCollection'; geometries: GeoJsonGeometry[] };

/**
 * Every run of line in a GeoJSON geometry, as map-ready coordinates.
 *
 * PostGIS set operations return whatever shape fits: a plain line, a multi-line
 * once a subtraction cuts it apart, or an empty collection when nothing is left.
 * Callers get zero or more polylines and never branch on the geometry type.
 *
 * PostGIS — and GeoJSON generally — orders a position `[longitude, latitude]`,
 * while every map library orders it `{ latitude, longitude }`. Getting the two
 * backwards is the classic silent geo bug: it renders Paris in the Indian Ocean
 * and looks perfectly reasonable in a diff.
 *
 * So the flip happens in exactly one place, and nothing else in the codebase
 * indexes a raw coordinate pair.
 */
export function toLineStrings(geoJson: string): Coordinate[][] {
  return linesOf(JSON.parse(geoJson) as GeoJsonGeometry).filter((line) => line.length > 0);
}

function linesOf(geometry: GeoJsonGeometry): Coordinate[][] {
  switch (geometry.type) {
    case 'LineString':
      return [geometry.coordinates.map(toCoordinate)];
    case 'MultiLineString':
      return geometry.coordinates.map((line) => line.map(toCoordinate));
    case 'GeometryCollection':
      return geometry.geometries.flatMap(linesOf);
  }
}

function toCoordinate([longitude, latitude]: [number, number]): Coordinate {
  return { latitude, longitude };
}

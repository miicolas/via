/** A WGS84 position in the shape the map client consumes. */
export type Coordinate = {
  latitude: number;
  longitude: number;
};

type GeoJsonLineString = {
  type: 'LineString';
  coordinates: [number, number][];
};

/**
 * PostGIS — and GeoJSON generally — orders a position `[longitude, latitude]`,
 * while every map library orders it `{ latitude, longitude }`. Getting the two
 * backwards is the classic silent geo bug: it renders Paris in the Indian Ocean
 * and looks perfectly reasonable in a diff.
 *
 * So the flip happens in exactly one place, and nothing else in the codebase
 * indexes a raw coordinate pair.
 */
export function toCoordinates(geoJson: string): Coordinate[] {
  const line = JSON.parse(geoJson) as GeoJsonLineString;

  return line.coordinates.map(([longitude, latitude]) => ({ latitude, longitude }));
}

/**
 * Same rule as `geo/coordinates.ts`: a geometry primitive declares its own
 * shape rather than depending on the wire contract.
 */
type Coordinate = {
  latitude: number;
  longitude: number;
};

const EARTH_RADIUS_METERS = 6_371_000;

/**
 * Great-circle distance in meters. Every distance the search returns comes from
 * this one function, whichever kind of result carries it — PostGIS' geography
 * distance only *orders* rows, it never reaches the client.
 */
export function haversineMeters(a: Coordinate, b: Coordinate): number {
  const latA = toRadians(a.latitude);
  const latB = toRadians(b.latitude);
  const deltaLat = toRadians(b.latitude - a.latitude);
  const deltaLon = toRadians(b.longitude - a.longitude);

  const half =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(latA) * Math.cos(latB) * Math.sin(deltaLon / 2) ** 2;

  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(half));
}

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

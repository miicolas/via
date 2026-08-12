import { haversineMeters } from './distance';

/**
 * Same rule as `geo/coordinates.ts`: a geometry primitive declares its own
 * shape rather than depending on the wire contract.
 */
type Coordinate = {
  latitude: number;
  longitude: number;
};

/** Ground length of a polyline in meters. */
export function lineLengthMeters(coordinates: Coordinate[]): number {
  let length = 0;
  for (let i = 1; i < coordinates.length; i++) {
    length += haversineMeters(coordinates[i - 1], coordinates[i]);
  }
  return length;
}

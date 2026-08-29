import type { Coordinate, MapCoordinate } from "../journey-share-types";

export function toMapCoordinate(coordinate: Coordinate): MapCoordinate {
  return [coordinate.longitude, coordinate.latitude];
}

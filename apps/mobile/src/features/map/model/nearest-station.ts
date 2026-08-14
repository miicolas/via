import type { Coordinate, NetworkStation } from '@via/contract';

import type { StationFocus } from '@/features/map/model/types';

export function nearestStation(
  stations: NetworkStation[],
  origin: Coordinate
): StationFocus | undefined {
  let nearest: StationFocus | undefined;

  for (const station of stations) {
    const distanceMeters = distanceBetween(origin, station.coordinate);
    if (!nearest || distanceMeters < (nearest.distanceMeters ?? Infinity)) {
      nearest = { station, coordinate: station.coordinate, distanceMeters };
    }
  }

  return nearest;
}

function distanceBetween(a: Coordinate, b: Coordinate) {
  const earthRadiusMeters = 6_371_000;
  const latitudeDelta = toRadians(b.latitude - a.latitude);
  const longitudeDelta = toRadians(b.longitude - a.longitude);
  const latitudeA = toRadians(a.latitude);
  const latitudeB = toRadians(b.latitude);
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(latitudeA) * Math.cos(latitudeB) * Math.sin(longitudeDelta / 2) ** 2;

  return 2 * earthRadiusMeters * Math.asin(Math.sqrt(haversine));
}

function toRadians(value: number) {
  return (value * Math.PI) / 180;
}

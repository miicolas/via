import type { Coordinate, NetworkStation } from '@via/contract';

import type { StationFocus } from '@/features/map/model/types';
import { distanceBetween } from './distance-between';

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

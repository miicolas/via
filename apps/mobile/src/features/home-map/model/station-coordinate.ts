import type { Coordinate, NetworkStation } from '@via/contract';

export function stationCoordinate(station: NetworkStation): Coordinate | undefined {
  return Object.values(station.positions)[0];
}

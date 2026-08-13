import type { NetworkRoute, NetworkStation } from '@via/contract';

export function routesForStation(
  routes: NetworkRoute[],
  station: NetworkStation | undefined
): NetworkRoute[] {
  if (!station) return [];
  return routes.filter((route) => station.positions[route.id]);
}

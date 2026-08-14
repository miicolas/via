import type { Coordinate, NetworkRoute, NetworkStation } from '@via/contract';

import { compareRoutes } from '@/lib/route-order';

/**
 * Everything the map screen knows about the network, as data.
 *
 * Deliberately free of React, React Native and the API client: it is the half of
 * the screen that can be exercised by calling a function, and the hook next door
 * is only the adapter that feeds it.
 */

/** A station shown as part of one specific line. */
export type LineStation = NetworkStation;

/**
 * A line and its stations, resolved together.
 *
 * The screen used to thread `selectedRoute` and `stations` down as two separate
 * props that had to correspond. Handing line 4's stations alongside line 1's
 * colour typechecked perfectly, and the bug lived in the calling rather than in
 * any module. Resolved as one value, the mismatch becomes inexpressible.
 */
export type LineView = {
  route: NetworkRoute;
  stations: LineStation[];
  interchangeCount: number;
};

/** Stands in for a line colour while no line is selected. */
export const PLACEHOLDER_ROUTE_COLOR = '#D1D1D6';

/**
 * Resolves the selected line, falling back to the first one — which is line 1,
 * because `sortRoutes` puts it there.
 */
export function resolveLine(
  lines: NetworkRoute[],
  stations: NetworkStation[],
  selectedRouteId: string | undefined
): LineView | undefined {
  const route = lines.find((line) => line.id === selectedRouteId) ?? lines[0];
  if (!route) return undefined;

  const lineStations = stations.filter((station) => station.routeIds.includes(route.id));

  return {
    route,
    stations: lineStations,
    interchangeCount: lineStations.filter(isInterchange).length,
  };
}

export function sortRoutes(routes: NetworkRoute[]): NetworkRoute[] {
  return [...routes].sort(compareRoutes);
}

/**
 * South-west and north-east corners of a line. Framing the camera only needs the
 * bounding box, so this avoids handing thousands of points to the native map.
 */
export function routeBounds(route: NetworkRoute): Coordinate[] {
  let minLatitude = Infinity;
  let minLongitude = Infinity;
  let maxLatitude = -Infinity;
  let maxLongitude = -Infinity;

  for (const segment of route.segments) {
    for (const { latitude, longitude } of segment.coordinates) {
      minLatitude = Math.min(minLatitude, latitude);
      maxLatitude = Math.max(maxLatitude, latitude);
      minLongitude = Math.min(minLongitude, longitude);
      maxLongitude = Math.max(maxLongitude, longitude);
    }
  }

  if (minLatitude === Infinity) return [];
  return [
    { latitude: minLatitude, longitude: minLongitude },
    { latitude: maxLatitude, longitude: maxLongitude },
  ];
}

export function isInterchange(station: NetworkStation): boolean {
  return station.routeIds.length > 1;
}

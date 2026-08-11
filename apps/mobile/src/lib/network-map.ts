import { type InferResponseType } from 'hono/client';

import { api } from '@/lib/api';

const getNetworkMap = api.api.network.map.$get;

export type NetworkMap = InferResponseType<typeof getNetworkMap, 200>;
export type NetworkRoute = NetworkMap['routes'][number];
export type NetworkStation = NetworkMap['stations'][number];
export type Coordinate = NetworkRoute['segments'][number]['coordinates'][number];
/** A station resolved to the position it occupies on one specific route. */
export type RouteStation = NetworkStation & { coordinate: Coordinate };

/** Stands in for a line colour while no line is selected. */
export const PLACEHOLDER_ROUTE_COLOR = '#D1D1D6';

export async function fetchNetworkMap(signal: AbortSignal): Promise<NetworkMap> {
  const response = await getNetworkMap({}, { init: { signal } });
  if (!response.ok) throw new Error(`API ${response.status}`);
  return response.json();
}

/** 1, 2, 3, 3bis, 4… — numeric part first, suffix as tie-breaker. */
export function sortRoutes(routes: NetworkRoute[]): NetworkRoute[] {
  return [...routes].sort((a, b) => {
    const [numberA, suffixA] = routeOrder(a.shortName);
    const [numberB, suffixB] = routeOrder(b.shortName);
    return numberA - numberB || suffixA.localeCompare(suffixB);
  });
}

/**
 * South-west and north-east corners of a line. Framing the camera only needs the
 * bounding box, so this avoids handing thousands of points to the native map.
 */
export function routeBounds(route: NetworkRoute | undefined): Coordinate[] {
  let minLatitude = Infinity;
  let minLongitude = Infinity;
  let maxLatitude = -Infinity;
  let maxLongitude = -Infinity;

  for (const segment of route?.segments ?? []) {
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

export function stationsOnRoute(
  stations: NetworkStation[],
  routeId: string | undefined
): RouteStation[] {
  if (!routeId) return [];
  return stations.flatMap((station) => {
    const coordinate = station.positions[routeId];
    return coordinate ? [{ ...station, coordinate }] : [];
  });
}

export function isInterchange(station: NetworkStation) {
  return station.routeIds.length > 1;
}

function routeOrder(shortName: string) {
  const match = /^(\d+)(.*)$/.exec(shortName);
  if (!match) return [Number.MAX_SAFE_INTEGER, shortName] as const;
  return [Number(match[1]), match[2]] as const;
}

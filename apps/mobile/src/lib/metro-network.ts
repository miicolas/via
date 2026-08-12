import type { Coordinate, NetworkMap, NetworkRoute, NetworkStation } from '@via/contract';

/**
 * Everything the map screen knows about the network, as data.
 *
 * Deliberately free of React, React Native and the API client: it is the half of
 * the screen that can be exercised by calling a function, and the hook next door
 * is only the adapter that feeds it.
 */

/** A station together with where it sits on one specific line. */
export type LineStation = NetworkStation & { coordinate: Coordinate };

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

export type NetworkState =
  | { status: 'loading' }
  | { status: 'error'; message: string }
  | { status: 'ready'; lines: NetworkRoute[]; stations: NetworkStation[]; line: LineView };

export const LOAD_FAILED_MESSAGE = 'Le réseau de transport ne peut pas être chargé pour le moment.';
export const EMPTY_NETWORK_MESSAGE = 'Aucune ligne de transport à afficher.';

/** Stands in for a line colour while no line is selected. */
export const PLACEHOLDER_ROUTE_COLOR = '#D1D1D6';

/**
 * The single derivation of what the screen should show.
 *
 * It used to be computed in the hook, reduced to a boolean by the screen, and
 * then derived a third time by the status overlay from a different variable —
 * so `status: 'error'` with no message rendered a spinner for ever. One function,
 * one answer, and the impossible combinations stop being constructible.
 *
 * A network that resolves to no line at all is an error, not an empty success:
 * that is what lets `ready` guarantee a line and spares every component below a
 * `| undefined` branch.
 */
export function networkState(
  network: NetworkMap | undefined,
  error: string | undefined,
  selectedRouteId: string | undefined
): NetworkState {
  if (!network) {
    return error ? { status: 'error', message: error } : { status: 'loading' };
  }

  const lines = sortRoutes(network.routes);
  const line = resolveLine(lines, network.stations, selectedRouteId);

  if (!line) return { status: 'error', message: EMPTY_NETWORK_MESSAGE };

  return { status: 'ready', lines, stations: network.stations, line };
}

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

  const lineStations = stations.flatMap((station) => {
    const coordinate = station.positions[route.id];
    return coordinate ? [{ ...station, coordinate }] : [];
  });

  return {
    route,
    stations: lineStations,
    interchangeCount: lineStations.filter(isInterchange).length,
  };
}

/** 1, 2, 3, 3bis, 4… — numeric part first, suffix as tie-breaker. */
export function sortRoutes(routes: NetworkRoute[]): NetworkRoute[] {
  return [...routes].sort((a, b) => {
    const modeDifference = modeOrder(a.mode) - modeOrder(b.mode);
    if (modeDifference !== 0) return modeDifference;
    const [numberA, suffixA] = routeOrder(a.shortName);
    const [numberB, suffixB] = routeOrder(b.shortName);
    return numberA - numberB || suffixA.localeCompare(suffixB);
  });
}

function modeOrder(mode: NetworkRoute['mode']) {
  return { metro: 0, rer: 1, bus: 2 }[mode];
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
  return Object.keys(station.positions).length > 1;
}

/** Every place where a station sits on one of the lines it serves. */
export function stationPositions(
  station: NetworkStation
): Array<{ routeId: string; coordinate: Coordinate }> {
  return Object.entries(station.positions).map(([routeId, coordinate]) => ({
    routeId,
    coordinate,
  }));
}

/**
 * The position used to focus the map on a station when no line is selected.
 * The network view uses it as one shared anchor for the station label, while
 * `stationPositions` supplies the colours of the serving lines.
 */
export function primaryPosition(
  station: NetworkStation
): { routeId: string; coordinate: Coordinate } | undefined {
  const [entry] = Object.entries(station.positions);
  return entry ? { routeId: entry[0], coordinate: entry[1] } : undefined;
}

/** Where to draw a station when no particular line is in focus. */
export function stationCoordinate(station: NetworkStation): Coordinate | undefined {
  return primaryPosition(station)?.coordinate;
}

function routeOrder(shortName: string) {
  const match = /^(\d+)(.*)$/.exec(shortName);
  if (!match) return [Number.MAX_SAFE_INTEGER, shortName] as const;
  return [Number(match[1]), match[2]] as const;
}

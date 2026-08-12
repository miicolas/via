import type { NetworkMap, NetworkRoute, NetworkSegment, NetworkStation } from '@via/contract';
import { networkMode } from '@via/db/schema';

import { toLineStrings } from '../../geo/coordinates';
import { lineLengthMeters } from '../../geo/line-length';
import type { NetworkPatternRow, NetworkStationPositionRow } from './queries';

/**
 * Normalising an additional pattern against the displayed track leaves confetti
 * wherever the two briefly drift past the duplicate tolerance — around stations, mostly.
 * Anything this short is such a leftover, not a branch or a loop.
 */
const MIN_SEGMENT_LENGTH_METERS = 80;

export function toNetworkMap(
  patternRows: NetworkPatternRow[],
  stationRows: NetworkStationPositionRow[]
): NetworkMap {
  const routes = toRoutes(patternRows);

  return {
    routes,
    stations: toStations(stationRows, routes),
  };
}

function toRoutes(rows: NetworkPatternRow[]): NetworkRoute[] {
  return [...Map.groupBy(rows, (row) => row.routeId).values()].map((routeRows) => {
    const [route] = routeRows;
    const mode = networkMode(route.routeType, route.shortName);
    if (!mode) throw new Error(`Unsupported route ${route.routeId}`);

    return {
      id: route.routeId,
      shortName: route.shortName,
      longName: route.longName,
      color: `#${route.color}`,
      textColor: `#${route.textColor}`,
      mode,
      // From every row on purpose: a return pattern whose track deduplicated
      // into nothing still names a destination.
      destinations: [...new Set(routeRows.map(({ headsign }) => headsign))],
      segments: routeRows.flatMap(toSegments),
    };
  });
}

/** Zero segments for a fully deduplicated pattern, several once a cut split it. */
function toSegments(row: NetworkPatternRow): NetworkSegment[] {
  return toLineStrings(row.geometry)
    .filter((coordinates) => lineLengthMeters(coordinates) >= MIN_SEGMENT_LENGTH_METERS)
    .map((coordinates, index) => ({ id: `${row.patternId}#${index}`, coordinates }));
}

function toStations(
  rows: NetworkStationPositionRow[],
  routes: NetworkRoute[]
): NetworkStation[] {
  const routeById = new Map(routes.map((route) => [route.id, route]));

  return [...Map.groupBy(rows, (row) => row.id).values()].map((stationRows) => {
    const [station] = stationRows;

    return {
      id: station.id,
      name: station.name,
      positions: Object.fromEntries(
        stationRows.map((row) => {
          const source = {
            latitude: Number(row.latitude),
            longitude: Number(row.longitude),
          };
          const route = routeById.get(row.routeId);
          const coordinate =
            route?.mode === 'bus' ? source : nearestCoordinateOnRoute(source, route) ?? source;

          return [row.routeId, coordinate];
        })
      ),
    };
  });
}

/** Snaps a stop to the normalized geometry the client will actually draw. */
function nearestCoordinateOnRoute(
  coordinate: { latitude: number; longitude: number },
  route: NetworkRoute | undefined
) {
  if (!route) return undefined;
  const latitudeScale = 111_320;
  const longitudeScale = latitudeScale * Math.cos((coordinate.latitude * Math.PI) / 180);
  let nearest: { distance: number; x: number; y: number } | undefined;

  for (const segment of route.segments) {
    for (let index = 1; index < segment.coordinates.length; index += 1) {
      const start = segment.coordinates[index - 1]!;
      const end = segment.coordinates[index]!;
      const startX = (start.longitude - coordinate.longitude) * longitudeScale;
      const startY = (start.latitude - coordinate.latitude) * latitudeScale;
      const deltaX = (end.longitude - start.longitude) * longitudeScale;
      const deltaY = (end.latitude - start.latitude) * latitudeScale;
      const lengthSquared = deltaX * deltaX + deltaY * deltaY;
      const progress = Math.max(
        0,
        Math.min(1, lengthSquared === 0 ? 0 : -(startX * deltaX + startY * deltaY) / lengthSquared)
      );
      const x = startX + progress * deltaX;
      const y = startY + progress * deltaY;
      const distance = Math.hypot(x, y);
      if (!nearest || distance < nearest.distance) nearest = { distance, x, y };
    }
  }

  return nearest
    ? {
        latitude: coordinate.latitude + nearest.y / latitudeScale,
        longitude: coordinate.longitude + nearest.x / longitudeScale,
      }
    : undefined;
}

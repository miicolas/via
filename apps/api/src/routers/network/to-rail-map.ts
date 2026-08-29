import type { NetworkRoute, NetworkSegment, NetworkStation, RailMap } from '@via/contract';

import { toLineStrings } from '../../geo/coordinates';
import { lineLengthMeters } from '../../geo/line-length';
import { toRouteBadge } from '../route-badge';
import { ACCESSIBILITY_CONDITION_LABELS } from '../accessibility-labels';
import { toStationFountains } from '../station-fountains';
import type { NetworkPatternRow, RailStationPositionRow } from './queries';

/**
 * Normalising an additional pattern against the displayed track leaves confetti
 * wherever the two briefly drift past the duplicate tolerance — around stations, mostly.
 * Anything this short is such a leftover, not a branch or a loop.
 */
const MIN_SEGMENT_LENGTH_METERS = 80;

export function toRailMap(
  patternRows: NetworkPatternRow[],
  stationRows: RailStationPositionRow[]
): RailMap {
  const routes = toRoutes(patternRows);

  return {
    routes,
    stations: toStations(stationRows, routes),
  };
}

function toRoutes(rows: NetworkPatternRow[]): NetworkRoute[] {
  return [...Map.groupBy(rows, (row) => row.routeId).values()].map((routeRows) => {
    const [route] = routeRows;

    return {
      ...toRouteBadge({ ...route, id: route.routeId }),
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
  rows: RailStationPositionRow[],
  routes: NetworkRoute[]
): NetworkStation[] {
  const routeById = new Map(routes.map((route) => [route.id, route]));

  return [...Map.groupBy(rows, (row) => row.id).values()].map((stationRows) => {
    // Rows arrive ordered by route id, so the anchor is the station's first
    // serving line — the same entry the client used to read out of `positions`.
    const [station] = stationRows;
    const source = {
      latitude: Number(station.latitude),
      longitude: Number(station.longitude),
    };

    return {
      id: station.id,
      name: station.name,
      coordinate: nearestCoordinateOnRoute(source, routeById.get(station.routeId)) ?? source,
      routeIds: stationRows.map((row) => row.routeId),
      ...(station.accessibilityCondition
        ? { accessibility: {
            condition: station.accessibilityCondition,
            label: ACCESSIBILITY_CONDITION_LABELS[station.accessibilityCondition],
            comment: station.accessibilityDetail ?? undefined,
          } }
        : {}),
      ...(station.toiletStopId
        ? { toilets: {
            label: 'Sanitaires disponibles',
            detail: station.toiletDetail ?? undefined,
          } }
        : {}),
      ...(station.fountainStopId && station.fountainCondition
        ? { fountains: toStationFountains(station.fountainCondition, station.fountainDetail) }
        : {}),
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

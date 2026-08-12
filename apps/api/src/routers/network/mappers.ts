import type { NetworkMap, NetworkRoute, NetworkSegment, NetworkStation } from '@via/contract';

import { toLineStrings } from '../../geo/coordinates';
import { lineLengthMeters } from '../../geo/line-length';
import type { MetroPatternRow, MetroStationPositionRow } from './queries';

/**
 * Subtracting one direction's track from the other leaves confetti wherever the
 * two briefly drift past the duplicate tolerance — around stations, mostly.
 * Anything this short is such a leftover, not a branch or a loop.
 */
const MIN_SEGMENT_LENGTH_METERS = 80;

export function toNetworkMap(
  patternRows: MetroPatternRow[],
  stationRows: MetroStationPositionRow[]
): NetworkMap {
  return {
    routes: toRoutes(patternRows),
    stations: toStations(stationRows),
  };
}

function toRoutes(rows: MetroPatternRow[]): NetworkRoute[] {
  return [...Map.groupBy(rows, (row) => row.routeId).values()].map((routeRows) => {
    const [route] = routeRows;

    return {
      id: route.routeId,
      shortName: route.shortName,
      longName: route.longName,
      color: `#${route.color}`,
      textColor: `#${route.textColor}`,
      // From every row on purpose: a return pattern whose track deduplicated
      // into nothing still names a destination.
      destinations: [...new Set(routeRows.map(({ headsign }) => headsign))],
      segments: routeRows.flatMap(toSegments),
    };
  });
}

/** Zero segments for a fully deduplicated pattern, several once a cut split it. */
function toSegments(row: MetroPatternRow): NetworkSegment[] {
  return toLineStrings(row.geometry)
    .filter((coordinates) => lineLengthMeters(coordinates) >= MIN_SEGMENT_LENGTH_METERS)
    .map((coordinates, index) => ({ id: `${row.patternId}#${index}`, coordinates }));
}

function toStations(rows: MetroStationPositionRow[]): NetworkStation[] {
  return [...Map.groupBy(rows, (row) => row.id).values()].map((stationRows) => {
    const [station] = stationRows;

    return {
      id: station.id,
      name: station.name,
      positions: Object.fromEntries(
        stationRows.map((row) => [
          row.routeId,
          { latitude: Number(row.latitude), longitude: Number(row.longitude) },
        ])
      ),
    };
  });
}

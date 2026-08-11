import type { NetworkMap, NetworkRoute, NetworkStation } from '@via/contract';

import { toCoordinates } from '../../geo/coordinates';
import type { MetroPatternRow, MetroStationPositionRow } from './queries';

export function toNetworkMap(
  patternRows: MetroPatternRow[],
  stationRows: MetroStationPositionRow[]
): NetworkMap {
  return {
    routes: toRoutes(patternRows),
    stations: toStations(stationRows),
  };
}

/** One row per pattern, so a route's rows collapse into its segments. */
function toRoutes(rows: MetroPatternRow[]): NetworkRoute[] {
  return [...Map.groupBy(rows, (row) => row.routeId).values()].map((routeRows) => {
    const [route] = routeRows;

    return {
      id: route.routeId,
      shortName: route.shortName,
      longName: route.longName,
      // GTFS stores colours bare ("FFCD00"); the client wants them CSS-ready.
      color: `#${route.color}`,
      textColor: `#${route.textColor}`,
      segments: routeRows.map((row) => ({
        id: row.patternId,
        coordinates: toCoordinates(row.geometry),
      })),
    };
  });
}

/** One row per (station, route), so a station's rows are the lines it serves. */
function toStations(rows: MetroStationPositionRow[]): NetworkStation[] {
  return [...Map.groupBy(rows, (row) => row.id).values()].map((stationRows) => {
    const [station] = stationRows;

    return {
      id: station.id,
      name: station.name,
      routeIds: stationRows.map((row) => row.routeId),
      // PostGIS aggregates come back as strings on some driver paths, and the
      // wire contract promises numbers.
      positions: Object.fromEntries(
        stationRows.map((row) => [
          row.routeId,
          { latitude: Number(row.latitude), longitude: Number(row.longitude) },
        ])
      ),
    };
  });
}

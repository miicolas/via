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

function toRoutes(rows: MetroPatternRow[]): NetworkRoute[] {
  return [...Map.groupBy(rows, (row) => row.routeId).values()].map((routeRows) => {
    const [route] = routeRows;

    return {
      id: route.routeId,
      shortName: route.shortName,
      longName: route.longName,
      color: `#${route.color}`,
      textColor: `#${route.textColor}`,
      destinations: [...new Set(routeRows.map(({ headsign }) => headsign))],
      segments: routeRows.map((row) => ({
        id: row.patternId,
        coordinates: toCoordinates(row.geometry),
      })),
    };
  });
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

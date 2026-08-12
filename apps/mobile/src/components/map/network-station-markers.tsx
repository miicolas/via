import type { Coordinate, NetworkRoute, NetworkStation } from '@via/contract';
import { memo, useMemo } from 'react';
import type { SharedValue } from 'react-native-reanimated';

import { StationMarker } from '@/components/map/station-marker';
import {
  primaryPosition,
  stationPositions,
} from '@/lib/metro-network';

const MAX_VISIBLE_LINE_COLORS = 5;

type NetworkStationMarkersProps = {
  /** Needed for the dots' colours and their stable display order. */
  routes: NetworkRoute[];
  stations: NetworkStation[];
  opacity: SharedValue<number>;
  tracksViewChanges: boolean;
  onSelectStation: (stationId: string, coordinate: Coordinate) => void;
};

/** Every station of the network, shown when no single line is in focus. */
export const NetworkStationMarkers = memo(function NetworkStationMarkers({
  opacity,
  routes,
  stations,
  tracksViewChanges,
  onSelectStation,
}: NetworkStationMarkersProps) {
  const routeById = useMemo(() => new Map(routes.map((route) => [route.id, route])), [routes]);
  const indexByRouteId = useMemo(
    () => new Map(routes.map((route, index) => [route.id, index])),
    [routes]
  );

  return stations.flatMap((station) => {
    const position = primaryPosition(station);
    if (!position) return [];

    const servingRoutes = stationPositions(station)
      .sort(
        (first, second) =>
          (indexByRouteId.get(first.routeId) ?? Number.MAX_SAFE_INTEGER) -
          (indexByRouteId.get(second.routeId) ?? Number.MAX_SAFE_INTEGER)
      )
      .flatMap(({ routeId }) => {
        const route = routeById.get(routeId);
        return route ? [route] : [];
      });
    const colors = servingRoutes
      .slice(0, MAX_VISIBLE_LINE_COLORS)
      .map((route) => route.color);
    const modes = [...new Set(servingRoutes.map((route) => route.mode))];

    return [
      <StationMarker
        key={station.id}
        coordinate={position.coordinate}
        name={station.name}
        colors={colors}
        lineCount={servingRoutes.length}
        modes={modes}
        opacity={opacity}
        onSelectStation={onSelectStation}
        stationId={station.id}
        tracksViewChanges={tracksViewChanges}
      />,
    ];
  });
});

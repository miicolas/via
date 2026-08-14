import type { Coordinate, NetworkStation, RouteBadge } from '@via/contract';
import { memo, useMemo } from 'react';
import type { SharedValue } from 'react-native-reanimated';

import { StationMarker } from '@/components/map/station-marker';
import { compareRoutes } from '@/lib/route-order';

const MAX_VISIBLE_LINE_COLORS = 5;

type NetworkStationMarkersProps = {
  /** Needed for the dots' colours; badges cover rail and viewport-loaded bus lines alike. */
  routes: RouteBadge[];
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

  return stations.map((station) => {
    const servingRoutes = station.routeIds
      .flatMap((routeId) => {
        const route = routeById.get(routeId);
        return route ? [route] : [];
      })
      .sort(compareRoutes);
    const colors = servingRoutes
      .slice(0, MAX_VISIBLE_LINE_COLORS)
      .map((route) => route.color);
    const modes = [...new Set(servingRoutes.map((route) => route.mode))];

    return (
      <StationMarker
        key={station.id}
        coordinate={station.coordinate}
        name={station.name}
        colors={colors}
        lineCount={servingRoutes.length}
        modes={modes}
        opacity={opacity}
        onSelectStation={onSelectStation}
        stationId={station.id}
        tracksViewChanges={tracksViewChanges}
      />
    );
  });
});

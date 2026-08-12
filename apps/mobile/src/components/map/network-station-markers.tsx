import type { NetworkRoute, NetworkStation } from '@via/contract';
import { memo, useMemo } from 'react';

import { StationMarker } from '@/components/map/station-marker';
import { isInterchange, PLACEHOLDER_ROUTE_COLOR, primaryPosition } from '@/lib/metro-network';

type NetworkStationMarkersProps = {
  /** Needed for the dots' colours: a station is drawn in one of its lines' colour. */
  routes: NetworkRoute[];
  stations: NetworkStation[];
};

/** Every station of the network, shown when no single line is in focus. */
export const NetworkStationMarkers = memo(function NetworkStationMarkers({
  routes,
  stations,
}: NetworkStationMarkersProps) {
  const colorByRoute = useMemo(
    () => new Map(routes.map((route) => [route.id, route.color])),
    [routes]
  );

  return stations.flatMap((station) => {
    const position = primaryPosition(station);
    if (!position) return [];

    return [
      <StationMarker
        key={station.id}
        coordinate={position.coordinate}
        color={colorByRoute.get(position.routeId) ?? PLACEHOLDER_ROUTE_COLOR}
        interchange={isInterchange(station)}
      />,
    ];
  });
});

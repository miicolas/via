import { memo } from 'react';
import { Polyline } from 'react-native-maps';

import type { NetworkRoute } from '@via/contract';

import { PLACEHOLDER_ROUTE_COLOR } from '@/lib/metro-network';
import { mapTraceRoutes } from '@/lib/map-trace-routes';

const ROUNDED = { lineCap: 'round', lineJoin: 'round' } as const;
const MUTED = { strokeColor: 'rgba(120,120,128,0.11)', strokeWidth: 2.5 };
const CASING = { strokeColor: 'rgba(255,255,255,0.92)', strokeWidth: 5.5 };
const SELECTED_WIDTH = 3.4;
const NETWORK_WIDTH = 3;

type RouteLinesProps = {
  muted?: boolean;
  routes: NetworkRoute[];
  selectedRoute: NetworkRoute | undefined;
};

/** The whole network greyed out, with the selected line drawn on top of a white casing. */
export const RouteLines = memo(function RouteLines({
  muted = false,
  routes,
  selectedRoute,
}: RouteLinesProps) {
  const tracedRoutes = mapTraceRoutes(routes);
  const tracedSelection = selectedRoute?.mode === 'bus' ? undefined : selectedRoute;

  if (!tracedSelection) {
    return tracedRoutes.flatMap((route) =>
      route.segments.map((segment) => (
        <Polyline
          key={`network-${segment.id}`}
          coordinates={segment.coordinates}
          strokeColor={muted ? MUTED.strokeColor : route.color}
          strokeWidth={muted ? MUTED.strokeWidth : NETWORK_WIDTH}
          {...ROUNDED}
        />
      ))
    );
  }

  const selected = [tracedSelection];
  const layers = [
    {
      key: 'muted',
      routes: tracedRoutes.filter((route) => route.id !== tracedSelection.id),
      ...MUTED,
    },
    { key: 'casing', routes: selected, ...CASING },
    {
      key: 'selected',
      routes: selected,
      strokeColor: tracedSelection.color ?? PLACEHOLDER_ROUTE_COLOR,
      strokeWidth: SELECTED_WIDTH,
    },
  ];

  return layers.flatMap(({ key, routes: layerRoutes, ...stroke }) =>
    layerRoutes.flatMap((route) =>
      route.segments.map((segment) => (
        <Polyline
          key={`${key}-${segment.id}`}
          coordinates={segment.coordinates}
          {...ROUNDED}
          {...stroke}
        />
      ))
    )
  );
});

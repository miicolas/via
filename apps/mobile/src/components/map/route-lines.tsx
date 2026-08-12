import { memo } from 'react';
import { Polyline } from 'react-native-maps';

import type { NetworkRoute } from '@via/contract';

import { PLACEHOLDER_ROUTE_COLOR } from '@/lib/metro-network';

const ROUNDED = { lineCap: 'round', lineJoin: 'round' } as const;
const MUTED = { strokeColor: 'rgba(120,120,128,0.11)', strokeWidth: 2.5 };
const CASING = { strokeColor: 'rgba(255,255,255,0.92)', strokeWidth: 5.5 };
const SELECTED_WIDTH = 3.4;
const NETWORK_WIDTH = 3;

type RouteLinesProps = {
  routes: NetworkRoute[];
  selectedRoute: NetworkRoute | undefined;
};

/** The whole network greyed out, with the selected line drawn on top of a white casing. */
export const RouteLines = memo(function RouteLines({ routes, selectedRoute }: RouteLinesProps) {
  if (!selectedRoute) {
    return routes.flatMap((route) =>
      route.segments.map((segment) => (
        <Polyline
          key={`network-${segment.id}`}
          coordinates={segment.coordinates}
          strokeColor={route.color}
          strokeWidth={NETWORK_WIDTH}
          {...ROUNDED}
        />
      ))
    );
  }

  const selected = selectedRoute ? [selectedRoute] : [];
  const layers = [
    { key: 'muted', routes: routes.filter((route) => route.id !== selectedRoute?.id), ...MUTED },
    { key: 'casing', routes: selected, ...CASING },
    {
      key: 'selected',
      routes: selected,
      strokeColor: selectedRoute?.color ?? PLACEHOLDER_ROUTE_COLOR,
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

import type { Coordinate, NetworkRoute } from '@via/contract';

import type { LineView } from '@/lib/metro-network';
import {
  METERS_PER_LATITUDE_DEGREE,
  nearestPointOnEdge,
  normalize,
  prepareCorridorRoutes,
  type LayoutRoute,
  type Point,
} from '@/lib/transit-map-corridors';

const LANE_SPACING_PIXELS = 6;

export type TransitRouteLayout = {
  metersPerLongitudeDegree: number;
  routes: LayoutRoute[];
};

export type TransitMapViewport = {
  latitudeDelta: number;
  longitudeDelta: number;
  width: number;
  height: number;
};

/**
 * Finds the places where distinct transit routes use the same visual corridor.
 *
 * This pass depends only on network data, not zoom, so the map can prepare it
 * once. A corridor has to stay parallel for a meaningful distance: two lines
 * merely brushing one another at an intersection must not suddenly fan out.
 */
export function prepareTransitRouteLayout(routes: NetworkRoute[]): TransitRouteLayout {
  const coordinates = routes.flatMap((route) =>
    route.segments.flatMap((segment) => segment.coordinates)
  );
  const referenceLatitude =
    coordinates.reduce((sum, coordinate) => sum + coordinate.latitude, 0) /
    Math.max(1, coordinates.length);
  const metersPerLongitudeDegree =
    METERS_PER_LATITUDE_DEGREE * Math.cos((referenceLatitude * Math.PI) / 180);
  return {
    metersPerLongitudeDegree,
    routes: prepareCorridorRoutes(routes, metersPerLongitudeDegree),
  };
}

/** Keeps every route legible by placing shared corridors in screen-space lanes. */
export function positionTransitRoutes(
  layout: TransitRouteLayout,
  viewport: TransitMapViewport
): NetworkRoute[] {
  const width = Math.max(1, viewport.width);
  const height = Math.max(1, viewport.height);
  const longitudePerPixel = viewport.longitudeDelta / width;
  const latitudePerPixel = viewport.latitudeDelta / height;

  return layout.routes.map((route) => ({
    ...route,
    segments: route.segments.map((segment) => ({
      id: segment.id,
      coordinates: segment.points.map((point) => {
        if (point.laneRouteIds.length === 1) return point.coordinate;

        const routeIndex = point.laneRouteIds.indexOf(route.id);
        const lane = routeIndex - (point.laneRouteIds.length - 1) / 2;
        const tangentOnScreen = normalize({
          x:
            point.tangent.x /
            layout.metersPerLongitudeDegree /
            Math.max(Number.EPSILON, longitudePerPixel),
          y:
            -point.tangent.y /
            METERS_PER_LATITUDE_DEGREE /
            Math.max(Number.EPSILON, latitudePerPixel),
        });
        const offsetPixels = lane * LANE_SPACING_PIXELS;
        const offsetX = -tangentOnScreen.y * offsetPixels;
        const offsetY = tangentOnScreen.x * offsetPixels;

        return {
          longitude:
            point.anchor.x / layout.metersPerLongitudeDegree + offsetX * longitudePerPixel,
          latitude:
            point.anchor.y / METERS_PER_LATITUDE_DEGREE - offsetY * latitudePerPixel,
        };
      }),
    })),
  }));
}

/** Moves a focused line's stations onto the same display geometry as its lane. */
export function alignLineWithRouteLayout(
  line: LineView | undefined,
  routes: NetworkRoute[]
): LineView | undefined {
  if (!line) return undefined;
  const route = routes.find((candidate) => candidate.id === line.route.id);
  if (!route) return line;

  return {
    ...line,
    route,
    stations: line.stations.map((station) => ({
      ...station,
      coordinate: nearestCoordinateOnRoute(station.coordinate, route) ?? station.coordinate,
    })),
  };
}

function nearestCoordinateOnRoute(
  coordinate: Coordinate,
  route: NetworkRoute
): Coordinate | undefined {
  const metersPerLongitudeDegree =
    METERS_PER_LATITUDE_DEGREE * Math.cos((coordinate.latitude * Math.PI) / 180);
  const point = {
    x: coordinate.longitude * metersPerLongitudeDegree,
    y: coordinate.latitude * METERS_PER_LATITUDE_DEGREE,
  };
  let nearest: { distance: number; point: Point } | undefined;

  for (const segment of route.segments) {
    for (let index = 1; index < segment.coordinates.length; index += 1) {
      const startCoordinate = segment.coordinates[index - 1]!;
      const endCoordinate = segment.coordinates[index]!;
      const candidate = nearestPointOnEdge(
        point,
        {
          x: startCoordinate.longitude * metersPerLongitudeDegree,
          y: startCoordinate.latitude * METERS_PER_LATITUDE_DEGREE,
        },
        {
          x: endCoordinate.longitude * metersPerLongitudeDegree,
          y: endCoordinate.latitude * METERS_PER_LATITUDE_DEGREE,
        }
      );
      if (!nearest || candidate.distance < nearest.distance) nearest = candidate;
    }
  }

  return nearest
    ? {
        latitude: nearest.point.y / METERS_PER_LATITUDE_DEGREE,
        longitude: nearest.point.x / metersPerLongitudeDegree,
      }
    : undefined;
}

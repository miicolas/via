import type { Coordinate, NetworkRoute } from '@via/contract';

export const METERS_PER_LATITUDE_DEGREE = 111_320;

const SHARED_CORRIDOR_TOLERANCE_METERS = 40;
const MIN_SHARED_CORRIDOR_METERS = 80;
const MIN_PARALLEL_DOT_PRODUCT = Math.cos((18 * Math.PI) / 180);

export type Point = { x: number; y: number };
type Vector = { x: number; y: number };

type LayoutPoint = {
  anchor: Point;
  coordinate: Coordinate;
  laneRouteIds: string[];
  tangent: Vector;
};

type LayoutSegment = {
  id: string;
  points: LayoutPoint[];
};

export type LayoutRoute = Omit<NetworkRoute, 'segments'> & { segments: LayoutSegment[] };

type Edge = {
  end: Point;
  routeId: string;
  start: Point;
  tangent: Vector;
};

type Match = { point: Point; routeId: string };

/** Finds meaningful shared corridors without reacting to simple crossings. */
export function prepareCorridorRoutes(
  routes: NetworkRoute[],
  metersPerLongitudeDegree: number
): LayoutRoute[] {
  const toPoint = (coordinate: Coordinate): Point => ({
    x: coordinate.longitude * metersPerLongitudeDegree,
    y: coordinate.latitude * METERS_PER_LATITUDE_DEGREE,
  });
  const routeOrder = new Map(routes.map((route, index) => [route.id, index]));
  const edges = buildEdges(routes, toPoint);
  const edgeGrid = indexEdges(edges);

  return routes.map((route) => ({
    ...route,
    segments: route.segments.map((segment) => {
      const projected = segment.coordinates.map(toPoint);
      const tangents = projected.map((_, index) => pointTangent(projected, index));
      const matches = projected.map((point, index) =>
        corridorMatches(point, tangents[index]!, route.id, edges, edgeGrid)
      );
      const retainedMatches = retainCorridorRuns(projected, matches);

      return {
        id: segment.id,
        points: segment.coordinates.map((coordinate, index) => {
          const point = projected[index]!;
          const pointMatches = retainedMatches[index]!;
          const laneRouteIds = [route.id, ...pointMatches.map((match) => match.routeId)].sort(
            (first, second) =>
              (routeOrder.get(first) ?? Number.MAX_SAFE_INTEGER) -
              (routeOrder.get(second) ?? Number.MAX_SAFE_INTEGER)
          );

          return {
            anchor: averagePoint([point, ...pointMatches.map((match) => match.point)]),
            coordinate,
            laneRouteIds,
            tangent: tangents[index]!,
          };
        }),
      };
    }),
  }));
}

function buildEdges(
  routes: NetworkRoute[],
  toPoint: (coordinate: Coordinate) => Point
): Edge[] {
  return routes.flatMap((route) =>
    route.segments.flatMap((segment) => {
      const points = segment.coordinates.map(toPoint);
      return points.slice(1).flatMap((end, index) => {
        const start = points[index]!;
        const tangent = normalize({ x: end.x - start.x, y: end.y - start.y });
        return magnitude(tangent) === 0 ? [] : [{ end, routeId: route.id, start, tangent }];
      });
    })
  );
}

function indexEdges(edges: Edge[]): Map<string, number[]> {
  const grid = new Map<string, number[]>();

  edges.forEach((edge, index) => {
    const minX = Math.floor(Math.min(edge.start.x, edge.end.x) / SHARED_CORRIDOR_TOLERANCE_METERS);
    const maxX = Math.floor(Math.max(edge.start.x, edge.end.x) / SHARED_CORRIDOR_TOLERANCE_METERS);
    const minY = Math.floor(Math.min(edge.start.y, edge.end.y) / SHARED_CORRIDOR_TOLERANCE_METERS);
    const maxY = Math.floor(Math.max(edge.start.y, edge.end.y) / SHARED_CORRIDOR_TOLERANCE_METERS);

    for (let x = minX; x <= maxX; x += 1) {
      for (let y = minY; y <= maxY; y += 1) {
        const key = `${x}:${y}`;
        const cell = grid.get(key) ?? [];
        cell.push(index);
        grid.set(key, cell);
      }
    }
  });

  return grid;
}

function corridorMatches(
  point: Point,
  tangent: Vector,
  routeId: string,
  edges: Edge[],
  edgeGrid: Map<string, number[]>
): Match[] {
  const cellX = Math.floor(point.x / SHARED_CORRIDOR_TOLERANCE_METERS);
  const cellY = Math.floor(point.y / SHARED_CORRIDOR_TOLERANCE_METERS);
  const candidateIndexes = new Set<number>();

  for (let x = cellX - 1; x <= cellX + 1; x += 1) {
    for (let y = cellY - 1; y <= cellY + 1; y += 1) {
      for (const index of edgeGrid.get(`${x}:${y}`) ?? []) candidateIndexes.add(index);
    }
  }

  const nearestByRoute = new Map<string, { distance: number; point: Point }>();
  for (const index of candidateIndexes) {
    const edge = edges[index]!;
    if (edge.routeId === routeId) continue;
    if (Math.abs(dot(tangent, edge.tangent)) < MIN_PARALLEL_DOT_PRODUCT) continue;

    const nearest = nearestPointOnEdge(point, edge.start, edge.end);
    if (nearest.distance > SHARED_CORRIDOR_TOLERANCE_METERS) continue;
    const current = nearestByRoute.get(edge.routeId);
    if (!current || nearest.distance < current.distance) nearestByRoute.set(edge.routeId, nearest);
  }

  return [...nearestByRoute].map(([matchedRouteId, nearest]) => ({
    point: nearest.point,
    routeId: matchedRouteId,
  }));
}

function retainCorridorRuns(points: Point[], matches: Match[][]): Match[][] {
  const retained = matches.map(() => [] as Match[]);
  const routeIds = new Set(
    matches.flatMap((pointMatches) => pointMatches.map((match) => match.routeId))
  );

  for (const routeId of routeIds) {
    let runStart: number | undefined;

    for (let index = 0; index <= matches.length; index += 1) {
      const isMatched = matches[index]?.some((match) => match.routeId === routeId) ?? false;
      if (isMatched && runStart === undefined) runStart = index;
      if (isMatched || runStart === undefined) continue;

      const runEnd = index - 1;
      let length = 0;
      for (let pointIndex = runStart + 1; pointIndex <= runEnd; pointIndex += 1) {
        length += distance(points[pointIndex - 1]!, points[pointIndex]!);
      }

      if (length >= MIN_SHARED_CORRIDOR_METERS) {
        for (let pointIndex = runStart; pointIndex <= runEnd; pointIndex += 1) {
          const match = matches[pointIndex]!.find((candidate) => candidate.routeId === routeId);
          if (match) retained[pointIndex]!.push(match);
        }
      }
      runStart = undefined;
    }
  }

  return retained;
}

function pointTangent(points: Point[], index: number): Vector {
  const start = points[Math.max(0, index - 1)] ?? { x: 0, y: 0 };
  const end = points[Math.min(points.length - 1, index + 1)] ?? start;
  let tangent = normalize({ x: end.x - start.x, y: end.y - start.y });

  // Geometry direction follows vehicle direction. Normalising it geographically
  // keeps lane ordering stable when another route stores the same track backwards.
  if (tangent.x < 0 || (tangent.x === 0 && tangent.y < 0)) {
    tangent = { x: -tangent.x, y: -tangent.y };
  }
  return tangent;
}

export function nearestPointOnEdge(point: Point, start: Point, end: Point) {
  const deltaX = end.x - start.x;
  const deltaY = end.y - start.y;
  const lengthSquared = deltaX * deltaX + deltaY * deltaY;
  const progress = Math.max(
    0,
    Math.min(
      1,
      lengthSquared === 0
        ? 0
        : ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) /
            lengthSquared
    )
  );
  const nearest = { x: start.x + progress * deltaX, y: start.y + progress * deltaY };
  return { distance: distance(point, nearest), point: nearest };
}

export function normalize(vector: Vector): Vector {
  const length = magnitude(vector);
  return length === 0 ? { x: 0, y: 0 } : { x: vector.x / length, y: vector.y / length };
}

function averagePoint(points: Point[]): Point {
  return {
    x: points.reduce((sum, point) => sum + point.x, 0) / points.length,
    y: points.reduce((sum, point) => sum + point.y, 0) / points.length,
  };
}

function magnitude(vector: Vector) {
  return Math.hypot(vector.x, vector.y);
}

function dot(first: Vector, second: Vector) {
  return first.x * second.x + first.y * second.y;
}

function distance(first: Point, second: Point) {
  return Math.hypot(first.x - second.x, first.y - second.y);
}

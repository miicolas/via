import type { MapCoordinate } from "../journey-share-types";

export function mapConfiguration(points: readonly MapCoordinate[]): {
  readonly center: MapCoordinate;
  readonly zoom: number;
  readonly bounds?: [MapCoordinate, MapCoordinate];
} {
  const fallback: MapCoordinate = [2.3522, 48.8566];
  if (points.length === 0) return { center: fallback, zoom: 12 };

  const longitudes = points.map(([longitude]) => longitude);
  const latitudes = points.map(([, latitude]) => latitude);
  const west = Math.min(...longitudes);
  const east = Math.max(...longitudes);
  const south = Math.min(...latitudes);
  const north = Math.max(...latitudes);
  const center: MapCoordinate = [(west + east) / 2, (south + north) / 2];

  if (west === east && south === north) return { center, zoom: 14 };
  return {
    center,
    zoom: 12,
    bounds: [
      [west, south],
      [east, north],
    ],
  };
}

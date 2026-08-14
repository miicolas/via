/**
 * Quantizes what the user sees into fixed 0.02° tiles.
 *
 * Tiles rather than the raw viewport because they make requests repeatable:
 * panning around a neighbourhood re-asks for the same handful of tile keys, so
 * an in-memory cache — and the HTTP cache under it — absorbs almost every
 * movement. The size keeps a tile within the API's 0.05° span cap while
 * covering a marker-zoom viewport in at most a few tiles.
 */

export const TILE_SIZE_DEGREES = 0.02;

export type ViewportRegion = {
  latitude: number;
  longitude: number;
  latitudeDelta: number;
  longitudeDelta: number;
};

export type TileBounds = {
  minLatitude: number;
  maxLatitude: number;
  minLongitude: number;
  maxLongitude: number;
};

/** The tiles covering a region, as stable keys the cache can index by. */
export function tilesForRegion(region: ViewportRegion): string[] {
  const south = region.latitude - region.latitudeDelta / 2;
  const north = region.latitude + region.latitudeDelta / 2;
  const west = region.longitude - region.longitudeDelta / 2;
  const east = region.longitude + region.longitudeDelta / 2;

  const firstRow = Math.floor(south / TILE_SIZE_DEGREES);
  const lastRow = Math.floor(north / TILE_SIZE_DEGREES);
  const firstColumn = Math.floor(west / TILE_SIZE_DEGREES);
  const lastColumn = Math.floor(east / TILE_SIZE_DEGREES);

  const keys: string[] = [];
  for (let row = firstRow; row <= lastRow; row += 1) {
    for (let column = firstColumn; column <= lastColumn; column += 1) {
      keys.push(`${row}:${column}`);
    }
  }
  return keys;
}

/** A tile key back to the bounding box the API expects. */
export function tileBounds(key: string): TileBounds {
  const [row, column] = key.split(':').map(Number);
  return {
    minLatitude: row * TILE_SIZE_DEGREES,
    maxLatitude: (row + 1) * TILE_SIZE_DEGREES,
    minLongitude: column * TILE_SIZE_DEGREES,
    maxLongitude: (column + 1) * TILE_SIZE_DEGREES,
  };
}

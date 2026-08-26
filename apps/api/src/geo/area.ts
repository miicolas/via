/**
 * Same rule as `geo/distance.ts`: a geometry primitive declares its own shape
 * rather than depending on the wire contract.
 */
type Coordinate = {
  latitude: number;
  longitude: number;
};

type BoundingBox = {
  minLatitude: number;
  maxLatitude: number;
  minLongitude: number;
  maxLongitude: number;
};

/**
 * Everything a viewport request keeps, whatever it is keeping. Docks and
 * scooters answer the same question about the same bounding box, and written
 * once per kind the inclusive/exclusive edge drifts between them.
 */
export function selectInArea<T extends { coordinate: Coordinate }>(
  items: readonly T[],
  area: BoundingBox
): T[] {
  return items.filter(({ coordinate }) =>
    coordinate.latitude >= area.minLatitude &&
    coordinate.latitude <= area.maxLatitude &&
    coordinate.longitude >= area.minLongitude &&
    coordinate.longitude <= area.maxLongitude
  );
}

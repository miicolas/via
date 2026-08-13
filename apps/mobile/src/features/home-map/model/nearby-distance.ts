export const MAX_NEARBY_DISTANCE_METERS = 500;

/** The 500 m boundary belongs to planning; only strictly closer stations are live. */
export function isNearbyDistance(distanceMeters: number | undefined) {
  return distanceMeters !== undefined && distanceMeters < MAX_NEARBY_DISTANCE_METERS;
}

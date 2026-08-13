/** Pace used to turn a straight-line distance into a walking estimate. */
const METERS_PER_MINUTE = 80;

/** Rounds up to a minute: "0 min à pied" reads as an error, not as "very close". */
export function walkingMinutes(distanceMeters: number | undefined) {
  return distanceMeters ? Math.max(1, Math.round(distanceMeters / METERS_PER_MINUTE)) : undefined;
}

/** French typography: the space before the unit does not break. */
const NBSP = ' ';

/**
 * "190 m" below a kilometer, "1,4 km" above — decimal comma, and no dangling
 * ",0" ("2 km", never "2,0 km"). The value comes straight from the API's
 * `distanceMeters`; the client only spells it.
 */
export function formatDistance(meters: number): string {
  const rounded = Math.round(meters);
  if (rounded < 1_000) return `${rounded}${NBSP}m`;

  const tenthsOfKm = Math.round(rounded / 100);
  const whole = Math.floor(tenthsOfKm / 10);
  const tenth = tenthsOfKm % 10;

  return tenth === 0 ? `${whole}${NBSP}km` : `${whole},${tenth}${NBSP}km`;
}

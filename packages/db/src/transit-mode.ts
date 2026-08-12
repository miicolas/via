/**
 * GTFS `route_type` — https://gtfs.org/schedule/reference/#routestxt
 *
 * The one place that knows which integer means which mode, and the one place
 * that converts. The writer used to compare the CSV field against the string
 * `'1'` while the reader compared the column against the number `1`: same fact,
 * two literals in two packages, nothing binding them. Importing the RER would
 * have widened the writer and left the reader silently returning metro only —
 * a change that typechecks, passes every test, and drops half the network off
 * the map.
 */
export const ROUTE_TYPE = {
  tram: 0,
  metro: 1,
  rail: 2,
  bus: 3,
  ferry: 4,
  cableTram: 5,
  aerialLift: 6,
  funicular: 7,
} as const;

export type TransitMode = keyof typeof ROUTE_TYPE;

export const RER_SHORT_NAMES = ['A', 'B', 'C', 'D', 'E'] as const;

/** The modes the public map exposes, in the order it presents them. */
export const NETWORK_MODES = ['metro', 'rer', 'bus'] as const;
export type NetworkMode = (typeof NETWORK_MODES)[number];

/**
 * Turns GTFS route metadata into the smaller, user-facing network Via shows.
 * GTFS type 2 also contains Transilien and TER routes; A–E are the five RER
 * lines requested for this map.
 */
export function networkMode(routeType: number, shortName: string): NetworkMode | undefined {
  if (routeType === ROUTE_TYPE.metro) return 'metro';
  if (routeType === ROUTE_TYPE.bus) return 'bus';
  if (
    routeType === ROUTE_TYPE.rail &&
    RER_SHORT_NAMES.includes(shortName.trim().toUpperCase() as (typeof RER_SHORT_NAMES)[number])
  ) {
    return 'rer';
  }
  return undefined;
}

/**
 * GTFS arrives as CSV text; the column is an integer. `Number('')` is 0, which
 * is a valid mode (tram), so an empty field is rejected rather than silently
 * read as one.
 */
export function isMode(rawRouteType: string, mode: TransitMode): boolean {
  if (rawRouteType.trim() === '') return false;

  return Number(rawRouteType) === ROUTE_TYPE[mode];
}

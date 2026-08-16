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

export const METRO_SHORT_NAMES = [
  '1',
  '2',
  '3',
  '3bis',
  '4',
  '5',
  '6',
  '7',
  '7bis',
  '8',
  '9',
  '10',
  '11',
  '12',
  '13',
  '14',
] as const;
export const RER_SHORT_NAMES = ['A', 'B', 'C', 'D', 'E'] as const;
export const TRAM_SHORT_NAMES = [
  'T1',
  'T2',
  'T3a',
  'T3b',
  'T4',
  'T5',
  'T6',
  'T7',
  'T8',
  'T9',
  'T10',
  'T11',
  'T12',
  'T13',
  'T14',
] as const;
export const TRANSILIEN_SHORT_NAMES = ['H', 'J', 'K', 'L', 'N', 'P', 'R', 'U', 'V'] as const;

/** The modes the public map exposes, in the order it presents them. */
export const NETWORK_MODES = ['metro', 'rer', 'transilien', 'tram', 'bus'] as const;
export type NetworkMode = (typeof NETWORK_MODES)[number];

/**
 * Turns GTFS route metadata into the smaller, user-facing network Via shows.
 * Exact name lists deliberately keep TER, airport rail shuttles, the funicular
 * and the cable car outside this network even when they share a GTFS route type.
 */
const NORMALIZED_METRO_NAMES = new Set<string>(METRO_SHORT_NAMES.map((name) => name.toUpperCase()));
const NORMALIZED_TRAM_NAMES = new Set<string>(TRAM_SHORT_NAMES.map((name) => name.toUpperCase()));
const NORMALIZED_RER_NAMES = new Set<string>(RER_SHORT_NAMES);
const NORMALIZED_TRANSILIEN_NAMES = new Set<string>(TRANSILIEN_SHORT_NAMES);

export function networkMode(routeType: number, shortName: string): NetworkMode | undefined {
  const normalizedName = shortName.trim().toUpperCase();
  switch (routeType) {
    case ROUTE_TYPE.metro:
      return NORMALIZED_METRO_NAMES.has(normalizedName) ? 'metro' : undefined;
    case ROUTE_TYPE.bus:
      return 'bus';
    case ROUTE_TYPE.tram:
      return NORMALIZED_TRAM_NAMES.has(normalizedName) ? 'tram' : undefined;
    case ROUTE_TYPE.rail:
      if (NORMALIZED_RER_NAMES.has(normalizedName)) return 'rer';
      if (NORMALIZED_TRANSILIEN_NAMES.has(normalizedName)) return 'transilien';
      return undefined;
    default:
      return undefined;
  }
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

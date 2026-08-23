/**
 * Where a place falls on `/illustrations/france-coverage.svg`.
 *
 * The illustration is a drawn map, not a projection anyone can look up, so the
 * mapping is calibrated on three points the drawing itself fixes: the marker
 * the designer placed on Île-de-France, the western tip of Brittany and the
 * Mediterranean shore at the bottom of the outline. The scales that fall out —
 * 24.048 px per degree of longitude, 35.478 per degree of latitude — sit at a
 * ratio of 1.475, which is sec(47.2°). That is the giveaway: the drawing is a
 * plain equirectangular map of France, and these two numbers reproduce it.
 *
 * Results are percentages of the illustration's own box, so they survive every
 * width the map is drawn at, and the zoom the map applies on small screens.
 */

/** The `viewBox` of the illustration, verbatim. */
const ILLUSTRATION = { width: 1362, height: 903.344, top: -515.344 } as const;

/** The Île-de-France marker: the one point the drawing pins to a real place. */
const ANCHOR = { x: 384.143, y: -56.418, latitude: 48.8566, longitude: 2.3522 } as const;

const PIXELS_PER_DEGREE = { longitude: 24.048, latitude: 35.478 } as const;

export interface GeoPoint {
  readonly latitude: number;
  readonly longitude: number;
}

export interface MapPosition {
  /** Percentage from the left edge of the illustration. */
  readonly left: number;
  /** Percentage from its top edge. */
  readonly top: number;
}

export function projectOnFranceMap({ latitude, longitude }: GeoPoint): MapPosition {
  const x = ANCHOR.x + (longitude - ANCHOR.longitude) * PIXELS_PER_DEGREE.longitude;
  const y = ANCHOR.y - (latitude - ANCHOR.latitude) * PIXELS_PER_DEGREE.latitude;

  return {
    left: (x / ILLUSTRATION.width) * 100,
    top: ((y - ILLUSTRATION.top) / ILLUSTRATION.height) * 100,
  };
}

/**
 * Where France sits inside the illustration, as a share of it. Small screens
 * scale the drawing up and slide it until this point is centred, so a country
 * that is a quarter of a Europe-wide map still fills a phone.
 */
export const FRANCE_FOCUS: MapPosition = { left: 27.4, top: 58 };

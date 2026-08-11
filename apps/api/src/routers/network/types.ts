import type { Coordinate } from '../../geo/coordinates';

/** One GTFS shape: a continuous run of track, drawn as a single polyline. */
export type NetworkSegment = {
  id: string;
  coordinates: Coordinate[];
};

export type NetworkRoute = {
  id: string;
  shortName: string;
  longName: string;
  color: string;
  textColor: string;
  segments: NetworkSegment[];
};

export type NetworkStation = {
  id: string;
  name: string;
  routeIds: string[];
  /**
   * Keyed by route id: an interchange sits at a different snapped point on each
   * line it serves, which is what lets the client move a single station dot as
   * the selected line changes.
   */
  positions: Record<string, Coordinate>;
};

/**
 * The `/api/network/map` wire contract.
 *
 * The mobile app derives its types from this response via `InferResponseType`
 * rather than importing this declaration, so changing anything here changes the
 * app. Annotating the mapper with it turns an accidental reshape into a compile
 * error in the API, at the mapper, instead of a silent prop drift five files
 * deep in the app.
 */
export type NetworkMap = {
  routes: NetworkRoute[];
  stations: NetworkStation[];
};

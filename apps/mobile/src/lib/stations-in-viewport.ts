import type { NetworkStation } from '@via/contract';

export type StationViewport = {
  latitude: number;
  longitude: number;
  latitudeDelta: number;
  longitudeDelta: number;
};

const VIEWPORT_PADDING = 0.2;

/** Keeps native map markers proportional to what the user can actually see. */
export function stationsInViewport(
  stations: NetworkStation[],
  viewport: StationViewport
): NetworkStation[] {
  const latitudeRadius = viewport.latitudeDelta * (0.5 + VIEWPORT_PADDING);
  const longitudeRadius = viewport.longitudeDelta * (0.5 + VIEWPORT_PADDING);
  const south = viewport.latitude - latitudeRadius;
  const north = viewport.latitude + latitudeRadius;
  const west = viewport.longitude - longitudeRadius;
  const east = viewport.longitude + longitudeRadius;

  return stations.filter(
    ({ coordinate }) =>
      coordinate.latitude >= south &&
      coordinate.latitude <= north &&
      coordinate.longitude >= west &&
      coordinate.longitude <= east
  );
}

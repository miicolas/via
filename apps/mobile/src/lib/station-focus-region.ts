import type { Coordinate } from '@via/contract';
import type { EdgePadding, Region } from 'react-native-maps';

const STATION_FOCUS_LATITUDE_DELTA = 0.006;
const STATION_FOCUS_LONGITUDE_DELTA = 0.006;

export function stationFocusRegion(
  coordinate: Coordinate,
  edgePadding: EdgePadding,
  viewportHeight: number
): Region {
  const height = Math.max(1, viewportHeight);
  const visibleTop = Math.min(height, Math.max(0, edgePadding.top));
  const visibleBottom = Math.max(visibleTop, height - Math.max(0, edgePadding.bottom));
  const visibleCenterY = (visibleTop + visibleBottom) / 2;
  const latitudeOffset =
    ((height / 2 - visibleCenterY) / height) * STATION_FOCUS_LATITUDE_DELTA;

  return {
    latitude: coordinate.latitude - latitudeOffset,
    longitude: coordinate.longitude,
    latitudeDelta: STATION_FOCUS_LATITUDE_DELTA,
    longitudeDelta: STATION_FOCUS_LONGITUDE_DELTA,
  };
}

import type { Coordinate } from '@via/contract';
import { Linking } from 'react-native';

/** Starts public-transit directions from the current position in Apple Maps. */
export function openJourneyInAppleMaps(destination: Coordinate) {
  const coordinates = `${destination.latitude},${destination.longitude}`;
  return Linking.openURL(`http://maps.apple.com/?daddr=${coordinates}&dirflg=r`);
}

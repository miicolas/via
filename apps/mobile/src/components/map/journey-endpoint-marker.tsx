import * as ReactNativeMaps from 'react-native-maps';
import type { Coordinate } from '@via/contract';
import { StyleSheet, View } from 'react-native';

const Marker = ReactNativeMaps.Marker ?? 'Marker';

type JourneyEndpointMarkerProps = {
  coordinate: Coordinate;
  kind: 'origin' | 'destination';
};

export function JourneyEndpointMarker({ coordinate, kind }: JourneyEndpointMarkerProps) {
  return (
    <Marker
      accessibilityLabel={kind === 'origin' ? 'Départ de l’itinéraire' : 'Arrivée de l’itinéraire'}
      anchor={{ x: 0.5, y: 0.5 }}
      coordinate={coordinate}
      tracksViewChanges={false}
      zIndex={30}>
      <View style={styles.halo}>
        <View style={[styles.dot, kind === 'destination' && styles.destination]} />
      </View>
    </Marker>
  );
}

const styles = StyleSheet.create({
  halo: {
    width: 22,
    height: 22,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 11,
    backgroundColor: '#FFFFFF',
    boxShadow: '0 1px 5px rgba(0,0,0,0.28)',
  },
  dot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#2F6B5B',
  },
  destination: {
    borderWidth: 3,
    borderColor: '#2F6B5B',
    backgroundColor: '#FFFFFF',
  },
});

import type { Coordinate } from '@via/contract';
import { StyleSheet, View } from 'react-native';
import { Marker } from 'react-native-maps';

type DevelopmentLocationMarkerProps = {
  coordinate: Coordinate;
};

/**
 * The blue "you are here" dot, drawn by hand for development builds where the
 * native user-location dot is unavailable.
 */
export function DevelopmentLocationMarker({ coordinate }: DevelopmentLocationMarkerProps) {
  return (
    <Marker coordinate={coordinate} tracksViewChanges={false}>
      <View style={styles.halo}>
        <View style={styles.dot} />
      </View>
    </Marker>
  );
}

const styles = StyleSheet.create({
  dot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#0A84FF',
    borderColor: '#FFFFFF',
    borderWidth: 2,
  },
  halo: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(10,132,255,0.18)',
  },
});

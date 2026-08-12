import type { Coordinate, NetworkMode } from '@via/contract';
import { Marker } from 'react-native-maps';
import { StyleSheet, Text, View } from 'react-native';
import Animated, { useAnimatedStyle, type SharedValue } from 'react-native-reanimated';

import { StationDot } from '@/components/map/station-dot';
import { StationModeBadge } from '@/components/map/station-mode-badge';

type StationMarkerProps = {
  coordinate: Coordinate;
  name: string;
  colors: string[];
  lineCount: number;
  modes: NetworkMode[];
  opacity: SharedValue<number>;
  onSelectStation: (stationId: string, coordinate: Coordinate) => void;
  stationId: string;
  tracksViewChanges: boolean;
};

/** A transit-stop label with mode badges and serving-line colours. */
export function StationMarker({
  coordinate,
  name,
  colors,
  lineCount,
  modes,
  opacity,
  onSelectStation,
  stationId,
  tracksViewChanges,
}: StationMarkerProps) {
  const animatedStyle = useAnimatedStyle(() => ({ opacity: opacity.value }));

  return (
    <Marker
      accessible
      accessibilityHint="Affiche les lignes et les prochains passages"
      accessibilityLabel={`${name}, ${lineCount} ligne${lineCount > 1 ? 's' : ''}`}
      accessibilityRole="button"
      coordinate={coordinate}
      identifier={stationId}
      // The line runs through the colour badges; the station name hangs below.
      anchor={{ x: 0.5, y: 0.27 }}
      onPress={() => onSelectStation(stationId, coordinate)}
      tracksViewChanges={tracksViewChanges}
    >
      <Animated.View
        // Animate the custom view: animated Marker props are ignored under Fabric.
        style={[styles.marker, animatedStyle]}
      >
        <View style={styles.lineBadges}>
          {modes.map((mode) => <StationModeBadge key={mode} mode={mode} />)}
          {colors.map((color, index) => (
            <StationDot key={`${color}-${index}`} color={color} />
          ))}
        </View>
        <Text ellipsizeMode="tail" numberOfLines={1} style={styles.name}>
          {name}
        </Text>
      </Animated.View>
    </Marker>
  );
}

const styles = StyleSheet.create({
  marker: { alignItems: 'center', gap: 3 },
  lineBadges: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  name: {
    maxWidth: 170,
    color: '#EAF0F4',
    fontFamily: 'Archivo_700Bold',
    fontSize: 15,
    lineHeight: 18,
    textAlign: 'center',
    textShadowColor: 'rgba(9,17,24,0.9)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 2,
  },
});

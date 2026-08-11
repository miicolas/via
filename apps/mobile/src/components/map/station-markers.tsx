import { memo, useMemo } from 'react';
import { Animated, StyleSheet, View } from 'react-native';
import { MarkerAnimated } from 'react-native-maps';

import { isInterchange, type RouteStation } from '@/lib/network-map';

const CENTER_OFFSET = { x: 0, y: 0 };

type StationMarkersProps = {
  stations: RouteStation[];
  color: string;
  /** Drives the fade-in as the user zooms in. */
  opacity: Animated.Value;
};

export const StationMarkers = memo(function StationMarkers({
  stations,
  color,
  opacity,
}: StationMarkersProps) {
  // Built once per colour rather than once per station — there are a few hundred of them.
  const dotStyles = useMemo(() => {
    const dot = [styles.dot, { backgroundColor: color }];
    return { dot, interchange: [...dot, styles.interchangeDot] };
  }, [color]);

  return stations.map((station) => (
    <MarkerAnimated
      key={station.id}
      coordinate={station.coordinate}
      centerOffset={CENTER_OFFSET}
      opacity={opacity}
    >
      <View style={isInterchange(station) ? dotStyles.interchange : dotStyles.dot} />
    </MarkerAnimated>
  ));
});

const styles = StyleSheet.create({
  dot: {
    width: 7.5,
    height: 7.5,
    borderRadius: 3.75,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.9)',
  },
  interchangeDot: {
    width: 9.5,
    height: 9.5,
    borderRadius: 4.75,
    borderWidth: 1.25,
  },
});

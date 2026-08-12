import type { Coordinate } from '@via/contract';
import { memo } from 'react';
import type { SharedValue } from 'react-native-reanimated';

import { StationMarker } from '@/components/map/station-marker';
import { type LineView } from '@/lib/metro-network';

type StationMarkersProps = {
  /** The line and its stations, as one value — the colour cannot belong to another line. */
  line: LineView;
  opacity: SharedValue<number>;
  onSelectStation: (stationId: string, coordinate: Coordinate) => void;
  tracksViewChanges: boolean;
};

export const StationMarkers = memo(function StationMarkers({
  line,
  opacity,
  onSelectStation,
  tracksViewChanges,
}: StationMarkersProps) {
  return line.stations.map((station) => (
    <StationMarker
      key={station.id}
      coordinate={station.coordinate}
      name={station.name}
      colors={[line.route.color]}
      lineCount={1}
      modes={[line.route.mode]}
      opacity={opacity}
      onSelectStation={onSelectStation}
      stationId={station.id}
      tracksViewChanges={tracksViewChanges}
    />
  ));
});

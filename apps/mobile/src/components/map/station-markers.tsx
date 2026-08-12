import { memo } from 'react';

import { StationMarker } from '@/components/map/station-marker';
import { isInterchange, type LineView } from '@/lib/metro-network';

type StationMarkersProps = {
  /** The line and its stations, as one value — the colour cannot belong to another line. */
  line: LineView;
};

export const StationMarkers = memo(function StationMarkers({ line }: StationMarkersProps) {
  return line.stations.map((station) => (
    <StationMarker
      key={station.id}
      coordinate={station.coordinate}
      color={line.route.color}
      interchange={isInterchange(station)}
    />
  ));
});

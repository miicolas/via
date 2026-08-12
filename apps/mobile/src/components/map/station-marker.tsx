import type { Coordinate } from '@via/contract';
import { Marker } from 'react-native-maps';

import { StationDot } from '@/components/map/station-dot';

type StationMarkerProps = {
  coordinate: Coordinate;
  /** The colour of the line the dot is drawn in. */
  color: string;
  interchange: boolean;
};

/** A station dot pinned to the map, shared by the line view and the whole-network view. */
export function StationMarker({ coordinate, color, interchange }: StationMarkerProps) {
  return (
    <Marker
      coordinate={coordinate}
      // The dot never changes once drawn; without this every camera move
      // re-renders a few hundred marker views.
      tracksViewChanges={false}
    >
      <StationDot color={color} interchange={interchange} />
    </Marker>
  );
}

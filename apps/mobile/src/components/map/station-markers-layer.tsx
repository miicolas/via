import type { Coordinate, NetworkRoute, NetworkStation } from '@via/contract';
import { useEffect, useState } from 'react';
import type { SharedValue } from 'react-native-reanimated';

import { NetworkStationMarkers } from '@/components/map/network-station-markers';
import { StationMarkers } from '@/components/map/station-markers';
import type { LineView } from '@/lib/metro-network';

const SNAPSHOT_REFRESH_DURATION_MS = 700;
const TRACKING_SETTLE_DURATION_MS = 100;

type StationMarkersLayerProps = {
  line: LineView | undefined;
  opacity: SharedValue<number>;
  routes: NetworkRoute[];
  stations: NetworkStation[];
  tracksViewChanges: boolean;
  visible: boolean;
  onSelectStation: (stationId: string, coordinate: Coordinate) => void;
};

/** Keeps native marker snapshots current while their map-owned opacity changes. */
export function StationMarkersLayer({
  line,
  opacity,
  routes,
  stations,
  tracksViewChanges,
  visible,
  onSelectStation,
}: StationMarkersLayerProps) {
  const [refreshingSnapshot, setRefreshingSnapshot] = useState(true);
  const [settlingOpacity, setSettlingOpacity] = useState(false);

  useEffect(() => {
    if (tracksViewChanges) {
      setSettlingOpacity(true);
      return;
    }

    const timeout = setTimeout(
      () => setSettlingOpacity(false),
      TRACKING_SETTLE_DURATION_MS
    );
    return () => clearTimeout(timeout);
  }, [tracksViewChanges]);

  // Track view changes for a beat after mount so snapshots capture late-loading marker content.
  useEffect(() => {
    const timeout = setTimeout(
      () => setRefreshingSnapshot(false),
      SNAPSHOT_REFRESH_DURATION_MS
    );
    return () => clearTimeout(timeout);
  }, []);

  if (!visible) return null;

  const shouldTrackViewChanges =
    tracksViewChanges || settlingOpacity || refreshingSnapshot;

  return line ? (
    <StationMarkers
      line={line}
      opacity={opacity}
      onSelectStation={onSelectStation}
      tracksViewChanges={shouldTrackViewChanges}
    />
  ) : (
    <NetworkStationMarkers
      opacity={opacity}
      routes={routes}
      stations={stations}
      onSelectStation={onSelectStation}
      tracksViewChanges={shouldTrackViewChanges}
    />
  );
}

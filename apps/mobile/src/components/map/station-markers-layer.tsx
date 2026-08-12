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
  markerSnapshotVersion: number;
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
  markerSnapshotVersion,
  onSelectStation,
}: StationMarkersLayerProps) {
  const [refreshingSnapshot, setRefreshingSnapshot] = useState(false);
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

  useEffect(() => {
    setRefreshingSnapshot(true);
    const timeout = setTimeout(
      () => setRefreshingSnapshot(false),
      SNAPSHOT_REFRESH_DURATION_MS
    );
    return () => clearTimeout(timeout);
  }, [markerSnapshotVersion]);

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

import type { Journey } from '@via/contract';
import * as ReactNativeMaps from 'react-native-maps';

import { JourneyEndpointMarker } from '@/components/map/journey-endpoint-marker';

// Keep the map primitive behind this tiny seam so unit tests can mock the map
// package with only the primitives they need. Native builds always provide it.
const Polyline = ReactNativeMaps.Polyline ?? 'Polyline';

type JourneyRouteLayerProps = { journey?: Journey };

/** Draws the selected itinerary above the muted network without owning camera state. */
export function JourneyRouteLayer({ journey }: JourneyRouteLayerProps) {
  if (!journey) return null;
  const first = journey.sections[0];
  const last = journey.sections.at(-1);
  const origin = first?.geometry[0] ?? first?.from.coordinate;
  const destination = last?.geometry.at(-1) ?? last?.to.coordinate;

  return (
    <>
      {journey.sections.map((section, index) => {
        if (section.geometry.length < 2) return null;
        const transitColor =
          section.route?.color ?? (section.type === 'walk' ? '#2F6B5B' : '#6C716D');
        return (
          <Polyline
            coordinates={section.geometry}
            key={`${journey.id}:${section.type}:${index}`}
            lineCap="round"
            lineJoin="round"
            lineDashPattern={
              section.type === 'walk' || section.type === 'transfer' ? [7, 5] : undefined
            }
            strokeColor={transitColor}
            strokeWidth={section.type === 'transit' ? 6 : 3}
          />
        );
      })}
      {origin ? <JourneyEndpointMarker coordinate={origin} kind="origin" /> : null}
      {destination ? (
        <JourneyEndpointMarker coordinate={destination} kind="destination" />
      ) : null}
    </>
  );
}

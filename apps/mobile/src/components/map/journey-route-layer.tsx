import type { Journey } from '@via/contract';
import * as ReactNativeMaps from 'react-native-maps';

import { JourneyEndpointMarker } from '@/components/map/journey-endpoint-marker';
import { journeySectionCoordinates } from '@/lib/journey-map-geometry';

// Keep the map primitive behind this tiny seam so unit tests can mock the map
// package with only the primitives they need. Native builds always provide it.
const Polyline = ReactNativeMaps.Polyline ?? 'Polyline';

type JourneyRouteLayerProps = { journey?: Journey };

/**
 * Draws the selected itinerary above the muted network without owning camera
 * state. Walking sections use the provider's street geometry, so the dashed
 * line follows sidewalks/roads when the journey source supplies them.
 */
export function JourneyRouteLayer({ journey }: JourneyRouteLayerProps) {
  if (!journey?.sections) return null;
  const first = journey.sections[0];
  const last = journey.sections.at(-1);
  const origin = first ? journeySectionCoordinates(first)[0] : undefined;
  const destination = last ? journeySectionCoordinates(last).at(-1) : undefined;

  return (
    <>
      {journey.sections.map((section, index) => {
        const coordinates = journeySectionCoordinates(section);
        if (coordinates.length < 2) return null;
        const transitColor =
          section.route?.color ?? (section.type === 'walk' ? '#2F6B5B' : '#6C716D');
        return (
          <Polyline
            coordinates={coordinates}
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

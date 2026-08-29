import { Flag, MapPin } from "lucide-react";
import { useMemo, type ReactNode } from "react";

import {
  Map,
  MapControls,
  MapMarker,
  MapRoute,
  MarkerContent,
} from "@/components/ui/map";
import { sectionTypeColors, type Journey } from "../journey-share-types";
import { cssColor } from "../lib/css-color";
import { mapConfiguration } from "../lib/map-configuration";
import { toMapCoordinate } from "../lib/to-map-coordinate";

export function JourneyShareMap({
  journey,
  selectedLeg,
}: {
  readonly journey: Journey;
  readonly selectedLeg: number;
}): ReactNode {
  const routes = useMemo(
    () =>
      journey.sections.flatMap((section, index) => {
        const coordinates = section.geometry.map(toMapCoordinate);
        if (coordinates.length < 2) return [];
        return [
          {
            key: "route-" + (section.id ?? index),
            id: "journey-share-" + index,
            index,
            coordinates,
            color: section.route
              ? cssColor(section.route.color, sectionTypeColors[section.type])
              : sectionTypeColors[section.type],
          },
        ];
      }),
    [journey.sections],
  );
  const map = useMemo(
    () => mapConfiguration(routes.flatMap((route) => route.coordinates)),
    [routes],
  );
  const endpoints = {
    origin: journey.sections[0]?.from,
    destination: journey.sections[journey.sections.length - 1]?.to,
  };

  return (
    <Map
      center={map.center}
      zoom={map.zoom}
      {...(map.bounds
        ? {
            bounds: map.bounds,
            fitBoundsOptions: { padding: 72, maxZoom: 14 },
          }
        : {})}
      minZoom={4}
      maxZoom={18}
    >
      <MapControls
        position="bottom-right"
        showZoom
        showCompass
        showFullscreen
      />
      {routes.map((route) => (
        <MapRoute
          key={route.key}
          id={route.id}
          coordinates={route.coordinates}
          color={route.color}
          width={route.index === selectedLeg ? 7 : 4}
          opacity={route.index === selectedLeg ? 1 : 0.48}
          interactive={false}
        />
      ))}
      {endpoints.origin && (
        <MapMarker
          longitude={endpoints.origin.coordinate.longitude}
          latitude={endpoints.origin.coordinate.latitude}
          anchor="bottom"
        >
          <MarkerContent>
            <div className="grid size-10 place-items-center rounded-[0.9rem] border-2 border-white bg-neutral-950 text-white shadow-xl">
              <MapPin className="size-4" aria-hidden="true" />
            </div>
          </MarkerContent>
        </MapMarker>
      )}
      {endpoints.destination && (
        <MapMarker
          longitude={endpoints.destination.coordinate.longitude}
          latitude={endpoints.destination.coordinate.latitude}
          anchor="bottom"
        >
          <MarkerContent>
            <div className="grid size-10 place-items-center rounded-[0.9rem] border-2 border-white bg-[#1872f7] text-white shadow-xl">
              <Flag className="size-4" aria-hidden="true" />
            </div>
          </MarkerContent>
        </MapMarker>
      )}
    </Map>
  );
}

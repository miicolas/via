import type { JourneyShareResponse, JourneySection } from "@via/contract";
import {
  publicJourneyShareResponseSchema,
  type PublicJourneyShareResponse,
} from "@via/contract/public";

/**
 * Explicit allowlist for the browser journey page. Every level is rebuilt so a
 * private contract field can never cross this public boundary accidentally.
 */
export function toPublicJourneyShare(
  response: JourneyShareResponse,
): PublicJourneyShareResponse {
  const projected = {
    snapshot: {
      schemaVersion: response.snapshot.schemaVersion,
      generatedAt: response.snapshot.generatedAt,
      locale: response.snapshot.locale,
      timeZone: response.snapshot.timeZone,
      journey: {
        durationSeconds: response.snapshot.journey.durationSeconds,
        walkingDurationSeconds:
          response.snapshot.journey.walkingDurationSeconds,
        transferCount: response.snapshot.journey.transferCount,
        departureAt: response.snapshot.journey.departureAt,
        arrivalAt: response.snapshot.journey.arrivalAt,
        status: response.snapshot.journey.status,
        warnings: response.snapshot.journey.warnings,
        sections: response.snapshot.journey.sections.map(toPublicSection),
      },
    },
    expiresAt: response.expiresAt,
  };

  return publicJourneyShareResponseSchema.parse(projected);
}

const toPublicSection = (section: JourneySection) => {
  return {
    ...(section.id === undefined ? {} : { id: section.id }),
    type: section.type,
    durationSeconds: section.durationSeconds,
    from: {
      name: section.from.name,
      coordinate: {
        latitude: section.from.coordinate.latitude,
        longitude: section.from.coordinate.longitude,
      },
    },
    to: {
      name: section.to.name,
      coordinate: {
        latitude: section.to.coordinate.latitude,
        longitude: section.to.coordinate.longitude,
      },
    },
    ...(section.departureAt === undefined
      ? {}
      : { departureAt: section.departureAt }),
    ...(section.arrivalAt === undefined
      ? {}
      : { arrivalAt: section.arrivalAt }),
    geometry: section.geometry.map((coordinate) => ({
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    })),
    stops: section.stops.map((stop) => ({
      name: stop.name,
      ...(stop.arrivalAt === undefined ? {} : { arrivalAt: stop.arrivalAt }),
      ...(stop.departureAt === undefined
        ? {}
        : { departureAt: stop.departureAt }),
    })),
    ...(section.route === undefined
      ? {}
      : {
          route: {
            shortName: section.route.shortName,
            longName: section.route.longName,
            color: section.route.color,
            textColor: section.route.textColor,
          },
        }),
    ...(section.direction === undefined
      ? {}
      : { direction: section.direction }),
  };
};

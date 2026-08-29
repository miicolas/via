import type { PublicJourneyShareResponse } from "@via/contract/public";

export function journeyEndpoints(share: PublicJourneyShareResponse): {
  readonly origin: PublicJourneyShareResponse["snapshot"]["journey"]["sections"][number]["from"];
  readonly destination: PublicJourneyShareResponse["snapshot"]["journey"]["sections"][number]["to"];
} {
  const sections = share.snapshot.journey.sections;
  return {
    origin: sections[0]?.from ?? {
      name: "Départ",
      coordinate: { latitude: 0, longitude: 0 },
    },
    destination: sections[sections.length - 1]?.to ?? {
      name: "Arrivée",
      coordinate: { latitude: 0, longitude: 0 },
    },
  };
}

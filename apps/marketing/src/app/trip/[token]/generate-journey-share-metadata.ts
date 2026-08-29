import type { Metadata } from "next";

import type { JourneySharePageProps } from "./journey-share-page-props";
import { loadJourneyShare } from "./lib/load-journey-share";
import { formatDuration, journeyEndpoints } from "@/lib/journey-share";
import { canonicalJourneyShareToken } from "@/lib/journey-share-token";
import { createPageMetadata } from "@/lib/metadata";

export async function generateJourneyShareMetadata({
  params,
}: JourneySharePageProps): Promise<Metadata> {
  const { token: rawToken } = await params;
  const token = canonicalJourneyShareToken(rawToken);
  const fallback: Metadata = {
    title: "Trajet partagé",
    description: "Consultez ce trajet partagé par Metyro.",
    robots: { index: false, follow: false },
  };

  try {
    const result = await loadJourneyShare(token);
    if (result.kind !== "ready") return fallback;

    const { origin, destination } = journeyEndpoints(result.share);
    const title = `${origin.name} → ${destination.name}`;
    const description = `Trajet partagé par Metyro · ${formatDuration(result.share.snapshot.journey.durationSeconds)}.`;
    const canonical = `/trip/${token}`;

    return {
      ...createPageMetadata({ title, description, path: canonical }),
      robots: { index: false, follow: false },
    };
  } catch {
    return fallback;
  }
}

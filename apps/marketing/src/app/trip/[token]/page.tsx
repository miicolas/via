import { dehydrate, HydrationBoundary } from "@tanstack/react-query";
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { cache, type ReactNode } from "react";

import { JourneySharePageClient } from "./page.client";
import { JourneyShareProviders } from "./providers";
import { journeySearchParamsCache } from "./search-params";
import {
  formatDuration,
  journeyEndpoints,
  fetchJourneyShare,
  journeyShareQueryOptions,
} from "@/lib/journey-share";
import { canonicalJourneyShareToken } from "@/lib/journey-share-token";
import { createPageMetadata } from "@/lib/metadata";
import { makeQueryClient } from "@/lib/query-client";

/**
 * L’aperçu du lien et la page qu’il ouvre lisent le même trajet. Sans ce cache,
 * `generateMetadata` et le rendu valident chacun de leur côté un instantané qui
 * porte toute la géométrie du trajet — le même zod, deux fois, par visite.
 */
const loadShare = cache(fetchJourneyShare);

type PageProps = {
  readonly params: Promise<{ token: string }>;
  readonly searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export async function generateMetadata({
  params,
}: PageProps): Promise<Metadata> {
  const { token: rawToken } = await params;
  const token = canonicalJourneyShareToken(rawToken);
  const fallback: Metadata = {
    title: "Trajet partagé",
    description: "Consultez ce trajet partagé par Metyro.",
    robots: { index: false, follow: false },
  };

  try {
    const result = await loadShare(token);
    if (result.kind !== "ready") return fallback;

    const { origin, destination } = journeyEndpoints(result.share);
    const title = `${origin.name} → ${destination.name}`;
    const description = `Trajet partagé par Metyro · ${formatDuration(result.share.snapshot.journey.durationSeconds)}.`;
    const canonical = `/trip/${token}`;

    // Un trajet partagé n'est indexable par personne : le reste — canonique,
    // vignette, carte Twitter — est celui de toutes les pages du site.
    return {
      ...createPageMetadata({ title, description, path: canonical }),
      robots: { index: false, follow: false },
    };
  } catch {
    return fallback;
  }
}

export default async function JourneySharePage({
  params,
  searchParams,
}: PageProps): Promise<ReactNode> {
  const { token: rawToken } = await params;
  const token = canonicalJourneyShareToken(rawToken);

  if (token !== rawToken) redirect(`/trip/${token}`);

  // Parse once on the server so the shared parser remains the source of truth;
  // the client component reads the same parser through useQueryStates.
  await journeySearchParamsCache.parse(searchParams);

  const queryClient = makeQueryClient();
  // Le même `loadShare` que la métadonnée : `prefetchQuery` garde sa tolérance
  // aux pannes, le client réessaiera si la lecture n'a rien donné.
  await queryClient.prefetchQuery({
    ...journeyShareQueryOptions(token),
    queryFn: () => loadShare(token),
  });

  return (
    <JourneyShareProviders>
      <HydrationBoundary state={dehydrate(queryClient)}>
        <JourneySharePageClient token={token} />
      </HydrationBoundary>
    </JourneyShareProviders>
  );
}

import { dehydrate, HydrationBoundary } from "@tanstack/react-query";
import { redirect } from "next/navigation";
import type { ReactNode } from "react";

import { loadJourneyShare } from "./lib/load-journey-share";
import type { JourneySharePageProps } from "./journey-share-page-props";
import { JourneySharePageClient } from "./page.client";
import { JourneyShareProviders } from "./providers";
import { journeySearchParamsCache } from "./search-params";
import { journeyShareQueryOptions } from "@/lib/journey-share";
import { canonicalJourneyShareToken } from "@/lib/journey-share-token";
import { makeQueryClient } from "@/lib/query-client";

export { generateJourneyShareMetadata as generateMetadata } from "./generate-journey-share-metadata";

export default async function JourneySharePage({
  params,
  searchParams,
}: JourneySharePageProps): Promise<ReactNode> {
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
    queryFn: () => loadJourneyShare(token),
  });

  return (
    <JourneyShareProviders>
      <HydrationBoundary state={dehydrate(queryClient)}>
        <JourneySharePageClient token={token} />
      </HydrationBoundary>
    </JourneyShareProviders>
  );
}

import { fetchJourneyShare } from "./fetch-journey-share";
import { journeyShareQueryKey } from "./journey-share-query-key";

export function journeyShareQueryOptions(token: string) {
  return {
    queryKey: journeyShareQueryKey(token),
    queryFn: ({ signal }: { signal: AbortSignal }) =>
      fetchJourneyShare(token, { signal }),
    staleTime: 60_000,
    refetchOnWindowFocus: false,
    retry: 1,
  } as const;
}

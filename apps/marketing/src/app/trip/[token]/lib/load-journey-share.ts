import { cache } from "react";

import { fetchJourneyShare } from "@/lib/journey-share";

const cachedJourneyShare = cache(fetchJourneyShare);

export function loadJourneyShare(token: string) {
  return cachedJourneyShare(token);
}

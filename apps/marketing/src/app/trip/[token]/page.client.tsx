"use client";

import { useQuery } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";
import { useQueryStates } from "nuqs";

import {
  journeyEndpoints,
  journeyShareQueryOptions,
} from "@/lib/journey-share";
import { JourneyShareContent } from "./components/journey-share-content";
import { JourneyShareErrorState } from "./components/journey-share-error-state";
import { JourneyShareHero } from "./components/journey-share-hero";
import { JourneyShareLoadingState } from "./components/journey-share-loading-state";
import { clamp } from "./lib/clamp";
import { safeLocale } from "./lib/safe-locale";
import { safeTimeZone } from "./lib/safe-time-zone";
import { journeySearchParams } from "./search-params";

export function JourneySharePageClient({
  token,
}: {
  readonly token: string;
}): ReactNode {
  const query = useQuery(journeyShareQueryOptions(token));
  const [{ leg, view }, setSearchParams] = useQueryStates(journeySearchParams);
  const [copied, setCopied] = useState(false);

  if (query.isPending && query.data === undefined) {
    return <JourneyShareLoadingState />;
  }
  if (query.isError) {
    return (
      <JourneyShareErrorState
        code="unavailable"
        onRetry={() => void query.refetch()}
      />
    );
  }

  const result = query.data;
  if (!result || result.kind === "error") {
    return (
      <JourneyShareErrorState
        code={result?.kind === "error" ? result.code : "unavailable"}
        onRetry={() => void query.refetch()}
      />
    );
  }

  const share = result.share;
  const journey = share.snapshot.journey;
  const selectedLeg = clamp(leg, 0, Math.max(journey.sections.length - 1, 0));
  const locale = safeLocale(share.snapshot.locale);
  const timeZone = safeTimeZone(share.snapshot.timeZone);
  const { origin, destination } = journeyEndpoints(share);

  const copyLink = async (): Promise<void> => {
    if (!navigator.clipboard) return;
    try {
      await navigator.clipboard.writeText(window.location.href);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2_000);
    } catch {
      // Keep the original label when the browser denies clipboard access.
    }
  };

  const selectLeg = (index: number): void => {
    void setSearchParams({ leg: index, view: "details" });
  };

  return (
    <main
      id="main-content"
      className="min-h-svh overflow-clip bg-background text-foreground"
    >
      <JourneyShareHero
        journey={journey}
        origin={origin.name}
        destination={destination.name}
        locale={locale}
        timeZone={timeZone}
        copied={copied}
        onCopy={() => void copyLink()}
      />
      <JourneyShareContent
        token={token}
        share={share}
        selectedLeg={selectedLeg}
        locale={locale}
        timeZone={timeZone}
        view={view}
        onSelectLeg={selectLeg}
        onViewChange={(nextView) => void setSearchParams({ view: nextView })}
      />
    </main>
  );
}

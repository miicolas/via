import type { FeaturesContent } from "@/constants/features";
import type { ReactNode } from "react";
import { CompanionCard } from "./companion-card";
import { DashboardCard } from "./dashboard-card";
import { FeatureHighlights } from "./feature-highlights";
import { IntelligenceCard } from "./intelligence-card";
import { OnboardingCard } from "./onboarding-card";

export function FeaturesSection({
  content,
}: {
  readonly content: FeaturesContent;
}): ReactNode {
  return (
    <section className="mb-32 w-full bg-background px-6">
      <div className="mx-auto max-w-5xl">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-[1fr_1.5fr]">
          <OnboardingCard content={content.onboarding} />
          <DashboardCard content={content.dashboard} />
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <IntelligenceCard content={content.intelligence} />
            <CompanionCard content={content.companion} />
          </div>
        </div>
        <FeatureHighlights content={content.highlights} />
      </div>
    </section>
  );
}

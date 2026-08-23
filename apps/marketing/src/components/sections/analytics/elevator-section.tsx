import { FeatureDemoTile } from "@/components/sections/features/feature-demo-tile";
import { SectionHeading } from "@/components/ui/section-heading";
import type { AnalyticsContent } from "@/constants/analytics-page";
import type { ReactNode } from "react";
import { AvailabilityGapList } from "./availability-gap-list";
import { ElevatorRealityDemo } from "./elevator-reality-demo";

export function ElevatorSection({
  content,
}: {
  readonly content: AnalyticsContent["elevators"];
}): ReactNode {
  return (
    <section className="w-full bg-frame px-6 py-20 sm:py-28">
      <div className="mx-auto max-w-5xl">
        <SectionHeading
          eyebrow={content.eyebrow}
          title={content.title}
          description={content.description}
          width="wide"
        />

        <div className="grid grid-cols-1 gap-4 md:grid-cols-5">
          <FeatureDemoTile
            title={content.live.title}
            hint={content.live.hint}
            index={0}
            className="md:col-span-3"
          >
            <ElevatorRealityDemo content={content.live} />
          </FeatureDemoTile>
          <FeatureDemoTile
            title={content.gap.title}
            hint={content.gap.hint}
            index={1}
            variant="primary"
            className="md:col-span-2"
          >
            <AvailabilityGapList content={content.gap} />
          </FeatureDemoTile>
        </div>
      </div>
    </section>
  );
}

import type { FeaturesContent } from "@/constants/features";
import { SectionHeading } from "@/components/ui/section-heading";
import type { ReactNode } from "react";
import { AccessibilityDemo } from "./accessibility-demo";
import { CrowdingDemo } from "./crowding-demo";
import { FavoritesDemo } from "./favorites-demo";
import { FeatureDemoTile } from "./feature-demo-tile";
import { ScheduleDemo } from "./schedule-demo";

export function FeatureHighlights({
  content,
}: {
  readonly content: FeaturesContent["highlights"];
}): ReactNode {
  return (
    <div className="mt-24">
      <SectionHeading
        eyebrow={content.eyebrow}
        title={content.title}
        description={content.description}
      />
      <div className="grid grid-cols-1 gap-4 md:grid-cols-5">
        <FeatureDemoTile
          title={content.crowding.title}
          hint={content.crowding.hint}
          index={0}
          className="md:col-span-3"
        >
          <CrowdingDemo content={content.crowding} />
        </FeatureDemoTile>
        <FeatureDemoTile
          title={content.accessibility.title}
          hint={content.accessibility.hint}
          index={1}
          className="md:col-span-2"
        >
          <AccessibilityDemo content={content.accessibility} />
        </FeatureDemoTile>
        <FeatureDemoTile
          title={content.schedule.title}
          hint={content.schedule.hint}
          index={2}
          className="md:col-span-2"
        >
          <ScheduleDemo content={content.schedule} />
        </FeatureDemoTile>
        <FeatureDemoTile
          title={content.favorites.title}
          hint={content.favorites.hint}
          index={3}
          variant="primary"
          className="md:col-span-3"
        >
          <FavoritesDemo content={content.favorites} />
        </FeatureDemoTile>
      </div>
    </div>
  );
}

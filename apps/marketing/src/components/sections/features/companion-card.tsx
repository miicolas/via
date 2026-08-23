import type { FeaturesContent } from "@/constants/features";
import { Reveal } from "@/components/ui/reveal";
import type { ReactNode } from "react";
import { JourneyShowcase } from "./journey-showcase";

export function CompanionCard({
  content,
}: {
  readonly content: FeaturesContent["companion"];
}): ReactNode {
  return (
    <Reveal
      distance={40}
      duration={0.8}
      delay={0.3}
      margin="-100px"
      className="group flex min-h-64 flex-col rounded-4xl bg-card-primary p-6 md:p-8"
    >
      <h3 className="text-xl leading-tight font-medium text-white transition-transform duration-500 ease-out group-hover:scale-105 md:text-2xl">
        {content.title}
      </h3>
      <div className="flex flex-1 flex-col justify-center pt-6">
        <JourneyShowcase activity={content.activity} screen={content.screen} />
      </div>
    </Reveal>
  );
}

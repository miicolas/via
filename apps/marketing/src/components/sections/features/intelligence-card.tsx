import type { FeaturesContent } from "@/constants/features";
import { Reveal } from "@/components/ui/reveal";
import type { ReactNode } from "react";
import { IntelligenceComposer } from "./intelligence-composer";

export function IntelligenceCard({
  content,
}: {
  readonly content: FeaturesContent["intelligence"];
}): ReactNode {
  return (
    <Reveal
      distance={40}
      duration={0.8}
      delay={0.2}
      margin="-100px"
      className="group flex min-h-64 flex-col rounded-4xl bg-card-secondary p-6 md:p-8"
    >
      <div className="transition-transform duration-500 ease-out group-hover:scale-105">
        <span className="bg-gradient-to-r from-indigo-500 via-purple-500 to-orange-400 bg-clip-text text-xs font-semibold tracking-wide text-transparent uppercase">
          {content.badge}
        </span>
        <h3 className="mt-2 text-xl leading-tight font-medium text-card-foreground md:text-2xl">
          {content.title}
        </h3>
      </div>
      <div className="flex flex-1 flex-col justify-center pt-6">
        <IntelligenceComposer prompts={content.prompts} />
      </div>
    </Reveal>
  );
}

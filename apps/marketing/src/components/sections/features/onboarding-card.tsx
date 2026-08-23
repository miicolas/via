import type { FeaturesContent } from "@/constants/features";
import { Reveal } from "@/components/ui/reveal";
import { ProductScreenshot } from "@/components/ui/product-screenshot";
import { screenshots } from "@/constants/screenshots";
import type { ReactNode } from "react";

export function OnboardingCard({
  content,
}: {
  readonly content: FeaturesContent["onboarding"];
}): ReactNode {
  return (
    <Reveal
      distance={40}
      duration={0.8}
      margin="-100px"
      className="group flex min-h-140 flex-col overflow-hidden rounded-4xl bg-card-primary p-8 pb-0 md:row-span-2"
    >
      <div className="relative z-10 mb-6 text-center transition-transform duration-500 ease-out group-hover:scale-105">
        <h3 className="mb-3 text-2xl leading-tight font-medium text-white md:text-4xl">
          {content.title}
        </h3>
        <p className="text-sm text-white/85">{content.description}</p>
      </div>
      <div className="flex flex-1 items-end justify-center transition-transform duration-500 ease-out group-hover:scale-[1.02]">
        <ProductScreenshot
          asset={screenshots.stationsOverview}
          className="w-56 translate-y-16 md:w-64"
          imageClassName="scale-[1.015]"
          sizes="(max-width: 768px) 224px, 256px"
        />
      </div>
    </Reveal>
  );
}

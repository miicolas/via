import type { FeaturesContent } from "@/constants/features";
import { Reveal } from "@/components/ui/reveal";
import { departurePreview } from "@/constants/departures";
import type { ReactNode } from "react";
import { LiveDepartureZoom } from "./live-departure-zoom";

export function DashboardCard({
  content,
}: {
  readonly content: FeaturesContent["dashboard"];
}): ReactNode {
  return (
    <Reveal
      distance={40}
      duration={0.8}
      delay={0.1}
      margin="-100px"
      className="group relative flex min-h-80 flex-col overflow-hidden rounded-4xl bg-card-secondary p-8 md:block"
    >
      <div className="relative z-10 max-w-48 transition-transform duration-500 ease-out group-hover:scale-105">
        <h3 className="mb-3 text-xl leading-tight font-medium text-card-foreground md:text-2xl md:whitespace-nowrap">
          {content.title}
        </h3>
        <p className="text-sm text-card-foreground-muted">
          {content.description}
        </p>
      </div>
      <div className="relative mt-10 flex min-h-44 items-center justify-center md:absolute md:inset-x-8 md:bottom-4 md:mt-0">
        <div
          className="absolute size-64 rounded-full border border-black/8"
          aria-hidden="true"
        />
        <div
          className="absolute size-44 rounded-full border border-black/8"
          aria-hidden="true"
        />
        <LiveDepartureZoom
          departure={departurePreview}
          className="relative z-10 w-full max-w-xl transition-transform duration-500 ease-out group-hover:-translate-y-1"
        />
      </div>
    </Reveal>
  );
}

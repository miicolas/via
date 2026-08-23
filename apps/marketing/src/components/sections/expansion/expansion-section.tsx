import { votableCities } from "@/constants/cities";
import { expansionContent } from "@/constants/expansion";
import { Reveal } from "@/components/ui/reveal";
import { fetchCityDemand } from "@/lib/city-demand";
import type { ReactNode } from "react";
import { CoverageMap } from "./coverage-map";

/**
 * Where Metyro runs, and where it is wanted next. The counts are read on the
 * server so the ranking is in the HTML a visitor — or a crawler — receives; the
 * map itself never depends on that request answering.
 */
export async function ExpansionSection(): Promise<ReactNode> {
  const board = await fetchCityDemand();

  return (
    <section
      id="coverage"
      className="relative w-full scroll-mt-24 overflow-hidden bg-[#242424] pt-20 pb-20 sm:pt-28 sm:pb-28"
      aria-labelledby="coverage-title"
    >
      <Reveal className="mx-auto mb-10 max-w-2xl px-6 text-center sm:mb-14">
        <span className="text-sm font-medium text-white/45">
          {expansionContent.eyebrow}
        </span>
        <h2
          id="coverage-title"
          className="mt-3 text-3xl font-semibold tracking-tight text-white sm:text-4xl lg:text-5xl"
        >
          {expansionContent.title}
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-base text-white/55 sm:text-lg">
          {expansionContent.description}
        </p>
      </Reveal>

      <CoverageMap cities={votableCities} board={board} />
    </section>
  );
}

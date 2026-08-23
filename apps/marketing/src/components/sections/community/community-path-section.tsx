import { Reveal } from "@/components/ui/reveal";
import type { CommunityContent } from "@/constants/community-page";
import type { ReactNode } from "react";

export function CommunityPathSection({
  content,
}: {
  readonly content: CommunityContent["path"];
}): ReactNode {
  return (
    <section className="w-full border-y border-accent/15 bg-frame px-6 py-24 sm:py-28">
      <div className="mx-auto max-w-5xl">
        <Reveal className="mb-14 max-w-2xl lg:mb-16">
          <span className="text-sm font-medium text-muted-foreground">
            {content.eyebrow}
          </span>
          <h2 className="mt-3 text-3xl font-semibold tracking-tight text-foreground sm:text-4xl lg:text-5xl">
            {content.title}
          </h2>
          <p className="mt-4 max-w-xl text-base text-muted-foreground sm:text-lg">
            {content.description}
          </p>
        </Reveal>
        <div className="grid gap-10 md:grid-cols-3 md:gap-8">
          {content.steps.map((step, index) => (
            <Reveal key={step.label} delay={index * 0.08} className="relative">
              <div className="flex items-baseline gap-3 border-t border-accent/20 pt-5">
                <span className="font-mono text-xs text-accent">
                  0{index + 1}
                </span>
                <span className="font-mono text-xs tracking-[0.12em] text-muted-foreground uppercase">
                  {step.label}
                </span>
              </div>
              <h3 className="mt-4 text-xl leading-snug font-medium text-foreground">
                {step.title}
              </h3>
              <p className="mt-2.5 text-sm leading-6 text-muted-foreground sm:text-base sm:leading-7">
                {step.description}
              </p>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

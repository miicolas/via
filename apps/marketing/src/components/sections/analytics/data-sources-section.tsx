import { Reveal } from "@/components/ui/reveal";
import { SectionHeading } from "@/components/ui/section-heading";
import { analyticsSources } from "@/constants/analytics-data";
import type { AnalyticsContent } from "@/constants/analytics-page";
import { ArrowUpRight } from "lucide-react";
import type { ReactNode } from "react";

export function DataSourcesSection({
  content,
}: {
  readonly content: AnalyticsContent["sources"];
}): ReactNode {
  return (
    <section id="sources" className="w-full scroll-mt-32 px-6 py-20 sm:py-28">
      <div className="mx-auto max-w-5xl">
        <SectionHeading
          eyebrow={content.eyebrow}
          title={content.title}
          description={content.description}
          width="wide"
        />

        <ul className="border-t border-foreground/10">
          {analyticsSources.map((source, index) => (
            <li key={source.href}>
              <Reveal
                distance={20}
                duration={0.6}
                delay={index * 0.06}
                margin="-60px"
              >
                <a
                  href={source.href}
                  target="_blank"
                  rel="noreferrer"
                  className="focus-ring group grid gap-4 border-b border-foreground/10 py-7 sm:grid-cols-[1fr_auto] sm:items-start sm:gap-10"
                >
                  <span>
                    <span className="flex items-baseline gap-2">
                      <span className="text-lg font-semibold tracking-tight text-foreground transition-colors duration-150 group-hover:text-accent sm:text-xl">
                        {source.title}
                      </span>
                      <ArrowUpRight
                        className="size-4 shrink-0 text-muted-foreground transition-transform duration-200 group-hover:-translate-y-0.5 group-hover:text-accent"
                        aria-hidden="true"
                      />
                    </span>
                    <span className="mt-2 block max-w-2xl text-sm leading-6 text-muted-foreground">
                      {source.scope}
                    </span>
                  </span>
                  <span className="flex shrink-0 items-center gap-2 text-xs font-medium text-muted-foreground sm:flex-col sm:items-end sm:gap-1 sm:pt-1">
                    <span className="text-foreground">{source.period}</span>
                    <span aria-hidden="true" className="sm:hidden">
                      ·
                    </span>
                    <span>{source.publisher}</span>
                  </span>
                </a>
              </Reveal>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

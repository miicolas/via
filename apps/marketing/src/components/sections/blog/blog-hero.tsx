import { PageHero } from "@/components/ui/page-hero";
import { SplitActionLink } from "@/components/ui/split-action-link";
import type { BlogContent } from "@/constants/blog";
import { ArrowUpRight } from "lucide-react";
import type { ReactNode } from "react";

export function BlogHero({
  content,
}: {
  readonly content: BlogContent["hero"];
}): ReactNode {
  return (
    <PageHero
      badge={content.badge}
      headline={content.headline}
      description={content.description}
    >
      <SplitActionLink {...content.primaryAction} />
      <a
        href={content.secondaryAction.href}
        className="focus-ring group inline-flex min-h-11 items-center gap-1.5 rounded-lg text-sm font-semibold text-foreground hover:text-accent"
      >
        {content.secondaryAction.label}
        <ArrowUpRight
          className="h-4 w-4 transition-transform duration-300 group-hover:-translate-y-0.5"
          aria-hidden="true"
        />
      </a>
    </PageHero>
  );
}

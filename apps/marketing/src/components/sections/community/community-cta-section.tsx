import { Reveal } from "@/components/ui/reveal";
import { SplitActionLink } from "@/components/ui/split-action-link";
import type { CommunityContent } from "@/constants/community-page";
import type { ReactNode } from "react";

export function CommunityCtaSection({
  content,
}: {
  readonly content: CommunityContent["cta"];
}): ReactNode {
  return (
    <section className="w-full px-6 pt-20 pb-20 sm:pt-28 sm:pb-28">
      <Reveal
        distance={30}
        duration={0.7}
        margin="-80px"
        className="mx-auto grid max-w-5xl gap-8 rounded-4xl bg-card-primary px-8 py-12 sm:px-12 sm:py-16 lg:grid-cols-[1fr_auto] lg:items-end"
      >
        <div className="max-w-2xl">
          <h2 className="text-3xl leading-tight font-medium tracking-tight text-balance text-white sm:text-4xl">
            {content.title}
          </h2>
          <p className="mt-5 text-base leading-7 text-white/70 sm:text-lg sm:leading-8">
            {content.description}
          </p>
        </div>
        <SplitActionLink {...content.action} tone="dark" />
      </Reveal>
    </section>
  );
}

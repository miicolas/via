import { MarketingIcon } from "@/components/ui/marketing-icon";
import { Reveal } from "@/components/ui/reveal";
import { SectionHeading } from "@/components/ui/section-heading";
import { blogContent } from "@/constants/blog";
import type { BlogContent } from "@/constants/blog";
import type { ReactNode } from "react";
import { JournalEntryRow } from "./journal-entry-row";

function LeadEntry({
  content,
}: {
  readonly content: BlogContent["index"];
}): ReactNode {
  const [lead] = blogContent.entries;

  return (
    <Reveal
      distance={30}
      duration={0.7}
      margin="-80px"
      className="grid gap-10 rounded-4xl bg-card-primary p-8 sm:p-12 lg:grid-cols-[1.25fr_0.75fr] lg:items-end"
    >
      <div>
        <div className="flex flex-wrap items-center gap-x-3 gap-y-2 text-xs font-semibold tracking-[0.08em] text-white/60 uppercase">
          <span className="grid size-10 place-items-center rounded-full bg-white/15 text-white">
            <MarketingIcon name={lead.icon} className="size-5" />
          </span>
          <span>{content.leadLabel}</span>
          <span aria-hidden="true">·</span>
          <span>{lead.category}</span>
          <span aria-hidden="true">·</span>
          <span>{lead.readingTime}</span>
          <span className="rounded-full bg-white/15 px-2.5 py-1 text-white normal-case">
            {content.statusLabel}
          </span>
        </div>
        <h3 className="mt-8 max-w-2xl text-3xl leading-[1.08] font-medium tracking-tight text-balance text-white sm:text-4xl lg:text-5xl">
          {lead.title}
        </h3>
      </div>
      <div>
        <p className="text-base leading-7 text-white/70">{lead.standfirst}</p>
        {lead.question ? (
          <p className="mt-5 border-t border-white/20 pt-4 text-sm leading-6 font-medium text-white">
            {lead.question}
          </p>
        ) : null}
      </div>
    </Reveal>
  );
}

export function JournalIndexSection({
  content,
}: {
  readonly content: BlogContent["index"];
}): ReactNode {
  const entries = blogContent.entries.slice(1);

  return (
    <section id="sommaire" className="w-full scroll-mt-32 px-6 py-20 sm:py-28">
      <div className="mx-auto max-w-5xl">
        <SectionHeading
          eyebrow={content.eyebrow}
          title={content.title}
          description={content.description}
          width="wide"
        />

        <LeadEntry content={content} />

        <ul className="mt-6 border-b border-foreground/10">
          {entries.map((entry, index) => (
            <JournalEntryRow
              key={entry.id}
              entry={entry}
              position={index + 2}
            />
          ))}
        </ul>
      </div>
    </section>
  );
}

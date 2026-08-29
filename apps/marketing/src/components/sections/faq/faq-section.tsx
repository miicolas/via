import type { PageContent } from "@/constants/page";
import type { FAQContent } from "@/constants/types";
import { Accordion } from "@/components/ui/accordion";
import { ActionLink } from "@/components/ui/action-link";
import { LaunchAction } from "@/components/ui/launch-action";
import { SectionHeading } from "@/components/ui/section-heading";
import type { ReactNode } from "react";

interface FAQSectionProps {
  readonly content: PageContent["faq"];
  readonly items: readonly FAQContent[];
}

export function FAQSection({ content, items }: FAQSectionProps): ReactNode {
  return (
    <section className="w-full px-6 py-20 sm:py-28">
      <div className="mx-auto max-w-3xl">
        <div className="mb-12 text-center sm:mb-16">
          <SectionHeading
            eyebrow={content.eyebrow}
            title={content.title}
            description={content.description}
          />
          <div className="-mt-4 flex flex-wrap items-center justify-center gap-3">
            <LaunchAction configuration={content.primaryAction} mode="button" />
            <ActionLink {...content.secondaryAction} variant="secondary" />
          </div>
        </div>
        <Accordion items={items} />
      </div>
    </section>
  );
}

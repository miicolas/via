import type { PageContent } from "@/constants/page";
import type { PricingPlanContent } from "@/constants/types";
import { SectionHeading } from "@/components/ui/section-heading";
import type { ReactNode } from "react";
import { PricingCard } from "./pricing-card";

interface PricingSectionProps {
  readonly content: PageContent["pricing"];
  readonly plans: readonly PricingPlanContent[];
}

export function PricingSection({
  content,
  plans,
}: PricingSectionProps): ReactNode {
  return (
    <section
      id="pricing"
      className="w-full scroll-mt-24 bg-background px-6 py-20 sm:py-28"
    >
      <div className="mx-auto max-w-5xl">
        <SectionHeading {...content} width="wide" />
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 lg:gap-8">
          {plans.map((plan, index) => (
            <PricingCard key={plan.name} plan={plan} index={index} />
          ))}
        </div>
      </div>
    </section>
  );
}

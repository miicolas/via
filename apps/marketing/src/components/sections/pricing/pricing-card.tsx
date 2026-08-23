import type { PricingPlanContent } from "@/constants/types";
import { ActionButton } from "@/components/ui/action-button";
import { Reveal } from "@/components/ui/reveal";
import { Check } from "lucide-react";
import type { ReactNode } from "react";

interface PricingCardProps {
  readonly plan: PricingPlanContent;
  readonly index: number;
}

export function PricingCard({ plan, index }: PricingCardProps): ReactNode {
  return (
    <Reveal distance={40} delay={index * 0.1} className="relative h-full">
      {plan.popular && (
        <div
          className="absolute -inset-1 rounded-[1.2em] bg-accent"
          aria-hidden="true"
        />
      )}
      <div
        className={`relative flex h-full flex-col rounded-2xl bg-frame p-6 sm:p-8 ${plan.popular ? "" : "border border-border"}`}
      >
        {plan.popular && (
          <div className="absolute -top-4 left-1/2 -translate-x-1/2">
            <span className="inline-block rounded-full bg-accent px-4 py-1.5 text-xs font-semibold tracking-wide text-white/90 uppercase">
              Most Popular
            </span>
          </div>
        )}
        <h3 className="text-xl font-semibold text-foreground">{plan.name}</h3>
        <div className="mt-4">
          <div className="flex items-end gap-3">
            <span className="text-5xl font-bold tracking-tight text-foreground">
              ${plan.price}
            </span>
            <span className="mb-1 text-sm text-muted-foreground">/month</span>
          </div>
          <p className="mt-2 text-sm text-muted-foreground">
            Billed annually, or ${plan.monthlyPrice}/mo billed monthly
          </p>
        </div>
        <ActionButton
          variant={plan.popular ? "primary" : "muted"}
          className="mt-6 w-full py-3"
        >
          Get Started
        </ActionButton>
        <div className="mt-8">
          <p className="text-sm font-medium text-muted-foreground">Includes:</p>
          <ul className="mt-4 space-y-3">
            {plan.features.map((feature) => (
              <li key={feature} className="flex items-center gap-3">
                <Check
                  className="h-4 w-4 shrink-0 text-foreground"
                  strokeWidth={2.5}
                />
                <span className="text-sm text-foreground">{feature}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </Reveal>
  );
}

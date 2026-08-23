import type { ProcessStepContent } from "@/constants/types";
import { CalendarCheck, Rocket, Users } from "lucide-react";
import type { ReactNode } from "react";

interface ProcessStepProps {
  readonly step: ProcessStepContent;
  readonly last: boolean;
}

export function ProcessStep({ step, last }: ProcessStepProps): ReactNode {
  const icons = {
    "calendar-check": CalendarCheck,
    users: Users,
    rocket: Rocket,
  } as const;
  const Icon = icons[step.icon];

  return (
    <div className={`relative flex gap-5 ${last ? "" : "pb-64"}`}>
      <div
        className="relative z-10 flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-accent"
        aria-hidden="true"
      >
        <Icon className="h-5 w-5 text-white" strokeWidth={2} />
      </div>
      <div className="pt-1">
        <h3 className="text-xl font-semibold text-foreground sm:text-2xl">
          {step.title}
        </h3>
        <p className="mt-2 max-w-sm text-base leading-relaxed text-foreground/60">
          {step.description}
        </p>
      </div>
    </div>
  );
}

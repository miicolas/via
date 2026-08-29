import type { ReactNode } from "react";

export function JourneyMetric({
  label,
  value,
}: {
  readonly label: string;
  readonly value: string;
}): ReactNode {
  return (
    <div className="min-w-0 px-3 text-center first:pl-0 last:pr-0 sm:px-5">
      <p className="text-[0.68rem] leading-tight text-neutral-500">{label}</p>
      <p className="mt-1 text-sm font-semibold text-neutral-950 tabular-nums sm:text-base">
        {value}
      </p>
    </div>
  );
}

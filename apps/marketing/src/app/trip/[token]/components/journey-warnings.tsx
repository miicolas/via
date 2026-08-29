import { TriangleAlert } from "lucide-react";
import type { ReactNode } from "react";

export function JourneyWarnings({
  warnings,
}: {
  readonly warnings: readonly string[];
}): ReactNode {
  return (
    <div
      className="mb-5 flex gap-4 rounded-[2rem] bg-[#fdf1e2] p-5 text-neutral-950 sm:p-6"
      role="note"
    >
      <span className="grid size-11 shrink-0 place-items-center rounded-[0.85rem] bg-[#e8590c] text-white">
        <TriangleAlert className="size-5" aria-hidden="true" />
      </span>
      <div className="min-w-0">
        <p className="font-semibold">À garder en tête</p>
        <ul className="mt-2 space-y-1.5 text-sm leading-6 text-neutral-600">
          {warnings.map((warning, index) => (
            <li key={warning + "-" + index}>{warning}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}

import { cn } from "@/lib/utils";
import type { ReactNode } from "react";
import { splitPlaceName } from "../lib/split-place-name";

export function RouteEndpoint({
  label,
  name,
  time,
  tone,
}: {
  readonly label: string;
  readonly name: string;
  readonly time: string;
  readonly tone: "origin" | "destination";
}): ReactNode {
  const place = splitPlaceName(name);

  return (
    <div className="flex min-w-0 items-start gap-4">
      <span
        className={cn(
          "mt-1 grid size-11 shrink-0 place-items-center rounded-[0.85rem] text-sm font-bold text-white shadow-sm",
          tone === "origin" ? "bg-neutral-950" : "bg-[#1872f7]",
        )}
        aria-hidden="true"
      >
        {tone === "origin" ? "A" : "B"}
      </span>
      <span className="min-w-0">
        <span className="block text-[0.68rem] font-semibold tracking-[0.14em] text-neutral-500 uppercase">
          {label} · {time}
        </span>
        <span className="mt-1 block text-xl leading-tight font-semibold tracking-tight text-balance sm:text-2xl">
          {place.primary}
        </span>
        {place.context && (
          <span className="mt-1 block text-sm text-neutral-500">
            {place.context}
          </span>
        )}
      </span>
    </div>
  );
}

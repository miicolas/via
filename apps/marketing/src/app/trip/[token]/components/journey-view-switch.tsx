import { ListTree, MapPin } from "lucide-react";
import type { ReactNode } from "react";

import { cn } from "@/lib/utils";
import type { JourneyView } from "../journey-share-types";

export function JourneyViewSwitch({
  view,
  onChange,
}: {
  readonly view: JourneyView;
  readonly onChange: (view: JourneyView) => void;
}): ReactNode {
  return (
    <div className="sticky top-20 z-40 mx-auto mb-6 grid w-full max-w-sm grid-cols-2 gap-1 rounded-2xl bg-foreground p-1.5 text-background shadow-xl lg:hidden">
      <button
        type="button"
        aria-pressed={view === "details"}
        onClick={() => onChange("details")}
        className={cn(
          "focus-ring inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold transition-colors",
          view === "details"
            ? "bg-background text-foreground"
            : "text-background/70 hover:text-background",
        )}
      >
        <ListTree className="size-4" aria-hidden="true" />
        Étapes
      </button>
      <button
        type="button"
        aria-pressed={view === "map"}
        onClick={() => onChange("map")}
        className={cn(
          "focus-ring inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold transition-colors",
          view === "map"
            ? "bg-background text-foreground"
            : "text-background/70 hover:text-background",
        )}
      >
        <MapPin className="size-4" aria-hidden="true" />
        Carte
      </button>
    </div>
  );
}

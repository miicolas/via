import type { ReactNode } from "react";

import { cn } from "@/lib/utils";
import type { JourneyTimelineRailStyle } from "../journey-share-types";

export function JourneyTimelineRailSegment({
  style,
  position,
  capAtNode,
}: {
  readonly style: JourneyTimelineRailStyle;
  readonly position: "above" | "below";
  readonly capAtNode: boolean;
}): ReactNode {
  if (style.kind === "none") return null;

  const positionClass =
    position === "above" ? "top-0 bottom-1/2" : "top-1/2 bottom-0";
  if (style.kind === "pedestrian") {
    return (
      <span
        className={cn("absolute left-1/2 w-1 -translate-x-1/2", positionClass)}
        style={{
          backgroundImage:
            "radial-gradient(circle, color-mix(in srgb, var(--muted-foreground) 74%, transparent) 2px, transparent 2.5px)",
          backgroundPosition: "center top",
          backgroundRepeat: "repeat-y",
          backgroundSize: "4px 12px",
        }}
        aria-hidden="true"
      />
    );
  }

  return (
    <span
      className={cn(
        "absolute left-1/2 w-5 -translate-x-1/2",
        positionClass,
        capAtNode &&
          (position === "above" ? "rounded-b-full" : "rounded-t-full"),
      )}
      style={{ backgroundColor: style.color }}
      aria-hidden="true"
    />
  );
}

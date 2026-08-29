import type { ReactNode } from "react";

import { cn } from "@/lib/utils";
import type {
  JourneyTimelineNode,
  JourneyTimelineRailStyle,
} from "../journey-share-types";
import { JourneyTimelineRailSegment } from "./journey-timeline-rail-segment";

export function JourneyTimelineRail({
  above,
  below,
  bead,
}: {
  readonly above: JourneyTimelineRailStyle;
  readonly below: JourneyTimelineRailStyle;
  readonly bead: JourneyTimelineNode["bead"];
}): ReactNode {
  const aboveContinues = above.kind === "transit" && below.kind === "transit";
  const belowContinues = below.kind === "transit" && above.kind === "transit";
  const hasTransitRail = above.kind === "transit" || below.kind === "transit";
  const beadSize = {
    terminus: "size-5",
    major: "size-4",
    minor: "size-2.5",
    none: "",
  }[bead];

  return (
    <span className="relative block h-full min-h-14 w-14 shrink-0">
      <JourneyTimelineRailSegment
        style={above}
        position="above"
        capAtNode={!aboveContinues}
      />
      <JourneyTimelineRailSegment
        style={below}
        position="below"
        capAtNode={!belowContinues}
      />
      {bead !== "none" && (
        <span
          className={cn(
            "absolute top-1/2 left-1/2 z-10 -translate-x-1/2 -translate-y-1/2 rounded-full",
            beadSize,
            hasTransitRail
              ? "bg-white shadow-[0_0_0_1px_rgba(0,0,0,0.05)]"
              : "border-[5px] border-accent bg-white",
          )}
          aria-hidden="true"
        />
      )}
    </span>
  );
}

import type { ReactNode } from "react";

import { formatDuration } from "@/lib/journey-share";
import { cn } from "@/lib/utils";
import {
  sectionTypeIcons,
  type JourneyTimelineNode,
} from "../journey-share-types";
import { cssColor } from "../lib/css-color";
import { formatJourneyTime } from "../lib/format-journey-time";
import { JourneyTimelineRail } from "./journey-timeline-rail";

export function JourneyTimelineNodeRow({
  node,
  selected,
  locale,
  timeZone,
  onSelect,
}: {
  readonly node: JourneyTimelineNode;
  readonly selected: boolean;
  readonly locale: string;
  readonly timeZone: string;
  readonly onSelect: () => void;
}): ReactNode {
  const routeColor = node.route
    ? cssColor(node.route.color, "#1872f7")
    : undefined;
  const Icon = sectionTypeIcons[node.sectionType];
  const isMovement = node.kind === "movement";
  const shownTime = isMovement ? node.endsAt : node.startsAt;

  return (
    <li>
      <button
        type="button"
        onClick={onSelect}
        aria-current={selected ? "step" : undefined}
        className={cn(
          "focus-ring grid w-full grid-cols-[3.5rem_minmax(0,1fr)_auto] items-stretch rounded-[1.5rem] pr-3 text-left transition-colors sm:pr-5",
          selected
            ? "bg-card-secondary"
            : "hover:bg-muted/65 focus-visible:bg-muted/65",
          node.kind === "stop" ? "min-h-14" : "min-h-20",
        )}
      >
        <JourneyTimelineRail
          above={node.railAbove}
          below={node.railBelow}
          bead={node.bead}
        />

        <span className="min-w-0 self-center py-3 pr-3">
          {node.eyebrow && (
            <span className="flex items-center gap-1.5 text-[0.68rem] font-semibold tracking-[0.12em] text-muted-foreground uppercase">
              {isMovement && <Icon className="size-3.5" aria-hidden="true" />}
              {node.eyebrow}
              {isMovement && (
                <>
                  <span aria-hidden="true">·</span>
                  {formatDuration(node.durationSeconds)}
                </>
              )}
            </span>
          )}
          <span
            className={cn(
              "block leading-snug tracking-tight text-balance",
              node.kind === "stop"
                ? "text-sm font-semibold sm:text-base"
                : "mt-1 text-base font-semibold sm:text-lg",
            )}
            style={routeColor ? { color: routeColor } : undefined}
          >
            {node.label}
          </span>
          {node.detail && (
            <span className="mt-1.5 block text-sm leading-5 text-muted-foreground">
              {node.detail}
            </span>
          )}
        </span>

        <time
          dateTime={shownTime}
          className="self-center text-sm font-semibold text-muted-foreground tabular-nums"
        >
          {formatJourneyTime(shownTime, locale, timeZone)}
        </time>
      </button>
    </li>
  );
}

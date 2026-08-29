import type { ReactNode } from "react";

import type { Journey } from "../journey-share-types";
import { buildJourneyTimeline } from "../lib/build-journey-timeline";
import { JourneyTimelineNodeRow } from "./journey-timeline-node-row";

export function JourneyTimeline({
  journey,
  selectedLeg,
  locale,
  timeZone,
  onSelectLeg,
}: {
  readonly journey: Journey;
  readonly selectedLeg: number;
  readonly locale: string;
  readonly timeZone: string;
  readonly onSelectLeg: (index: number) => void;
}): ReactNode {
  const nodes = buildJourneyTimeline(journey);

  return (
    <ol className="rounded-[2.5rem] bg-frame p-3 shadow-[0_24px_70px_rgba(0,0,0,0.08)] sm:p-5">
      {nodes.map((node) => (
        <JourneyTimelineNodeRow
          key={node.id}
          node={node}
          selected={selectedLeg === node.sectionIndex}
          locale={locale}
          timeZone={timeZone}
          onSelect={() => onSelectLeg(node.sectionIndex)}
        />
      ))}
    </ol>
  );
}

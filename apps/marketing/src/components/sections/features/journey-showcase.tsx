"use client";

import type { FeaturesContent } from "@/constants/features";
import { useReducedMotion } from "motion/react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DynamicIslandZoom } from "./dynamic-island-zoom";
import { JourneyActivityZoom } from "./journey-activity-zoom";

type Companion = FeaturesContent["companion"];

export function JourneyShowcase({
  activity,
  screen,
}: {
  readonly activity: Companion["activity"];
  readonly screen: Companion["screen"];
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const [phaseIndex, setPhaseIndex] = useState(0);
  const [expanded, setExpanded] = useState(true);
  const touchedRef = useRef(false);

  useEffect(() => {
    if (reduceMotion) return;

    let tick = 0;
    const interval = window.setInterval(() => {
      tick += 1;
      setPhaseIndex((index) => (index + 1) % activity.phases.length);
      if (!touchedRef.current && tick % 2 === 0) {
        setExpanded((value) => !value);
      }
    }, 2600);

    return () => window.clearInterval(interval);
  }, [activity.phases.length, reduceMotion]);

  const phase = activity.phases[phaseIndex] ?? activity.phases[0];
  if (!phase) return null;

  return (
    <div className="mx-auto w-full max-w-[272px] rounded-[2.4rem] bg-neutral-950 p-1.5 shadow-[0_24px_70px_rgba(0,0,0,0.35)]">
      <div className="rounded-[2rem] bg-gradient-to-b from-[#172554] via-[#312e81] to-[#4c1d95] px-3 pt-2.5 pb-3.5">
        <DynamicIslandZoom
          activity={activity}
          phase={phase}
          expanded={expanded}
          onToggle={() => {
            touchedRef.current = true;
            setExpanded((value) => !value);
          }}
        />
        <div className="mt-4 mb-5 text-center text-white">
          <p className="text-[0.65rem] font-medium tracking-wide text-white/70">
            {screen.date}
          </p>
          <p className="mt-0.5 text-4xl font-light tracking-tight tabular-nums">
            {screen.time}
          </p>
        </div>
        <JourneyActivityZoom activity={activity} phase={phase} />
      </div>
    </div>
  );
}

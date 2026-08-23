"use client";

import type { FeaturesContent } from "@/constants/features";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import type { ReactNode } from "react";

type JourneyActivity = FeaturesContent["companion"]["activity"];
type JourneyPhase = JourneyActivity["phases"][number];

const ISLAND_SPRING = { type: "spring", bounce: 0.3, duration: 0.55 } as const;

export function DynamicIslandZoom({
  activity,
  phase,
  expanded,
  onToggle,
}: {
  readonly activity: JourneyActivity;
  readonly phase: JourneyPhase;
  readonly expanded: boolean;
  readonly onToggle: () => void;
}): ReactNode {
  const reduceMotion = useReducedMotion();
  const spring = reduceMotion ? { duration: 0 } : ISLAND_SPRING;

  return (
    <motion.button
      layout
      type="button"
      onClick={onToggle}
      whileTap={reduceMotion ? {} : { scale: 0.96 }}
      transition={spring}
      className={`mx-auto flex cursor-pointer items-center overflow-hidden rounded-full bg-neutral-950 text-white ${expanded ? "gap-3 px-3.5 py-2.5" : "gap-2.5 px-3 py-2"}`}
      aria-expanded={expanded}
      aria-label={`Dynamic Island, ligne ${activity.line.shortName} vers ${activity.destination}, ${phase.minutes} minutes`}
    >
      <motion.span
        layout
        className={`grid shrink-0 place-items-center rounded-[0.45rem] font-bold ${expanded ? "size-7 text-sm" : "size-6 text-xs"}`}
        style={{
          backgroundColor: activity.line.color,
          color: activity.line.textColor,
        }}
        transition={spring}
        aria-hidden="true"
      >
        {activity.line.shortName}
      </motion.span>
      <AnimatePresence mode="popLayout" initial={false}>
        {expanded && (
          <motion.span
            key="details"
            layout
            initial={reduceMotion ? false : { opacity: 0, scale: 0.85 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={reduceMotion ? { opacity: 0 } : { opacity: 0, scale: 0.85 }}
            transition={spring}
            className="min-w-0 text-left"
            aria-hidden="true"
          >
            <span className="block max-w-32 truncate text-xs leading-tight font-semibold">
              {activity.destination}
            </span>
            <span className="block text-[0.65rem] leading-tight text-white/60">
              {phase.stop}
            </span>
          </motion.span>
        )}
      </AnimatePresence>
      <motion.span
        layout
        className="flex shrink-0 items-baseline gap-0.5 text-[#30d158]"
        transition={spring}
        aria-hidden="true"
      >
        <span className="relative grid h-5 min-w-3.5 place-items-center overflow-hidden text-base leading-none font-bold tabular-nums">
          <AnimatePresence initial={false} mode="popLayout">
            <motion.span
              key={phase.minutes}
              className="absolute"
              initial={reduceMotion ? false : { y: -16, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={reduceMotion ? {} : { y: 16, opacity: 0 }}
              transition={{ duration: 0.42, ease: [0.22, 1, 0.36, 1] }}
            >
              {phase.minutes}
            </motion.span>
          </AnimatePresence>
        </span>
        <span className="text-[0.6rem] font-semibold tracking-wide">
          {activity.unit}
        </span>
      </motion.span>
    </motion.button>
  );
}

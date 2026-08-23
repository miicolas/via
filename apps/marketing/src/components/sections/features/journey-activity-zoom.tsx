"use client";

import type { FeaturesContent } from "@/constants/features";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import type { ReactNode } from "react";

type JourneyActivity = FeaturesContent["companion"]["activity"];
type JourneyPhase = JourneyActivity["phases"][number];

export function JourneyActivityZoom({
  activity,
  phase,
  className = "",
}: {
  readonly activity: JourneyActivity;
  readonly phase: JourneyPhase;
  readonly className?: string;
}): ReactNode {
  const reduceMotion = useReducedMotion();

  return (
    <div
      className={`rounded-[1.4rem] bg-neutral-950/92 p-3.5 text-white shadow-[0_18px_50px_rgba(0,0,0,0.35)] backdrop-blur-xl ${className}`}
      aria-label={`Trajet en cours, ligne ${activity.line.shortName}, direction ${activity.destination}, ${phase.stop}, ${phase.minutes} minutes`}
    >
      <div className="flex items-center gap-2.5">
        <span
          className="grid size-8 shrink-0 place-items-center rounded-[0.55rem] text-sm font-bold"
          style={{
            backgroundColor: activity.line.color,
            color: activity.line.textColor,
          }}
          aria-hidden="true"
        >
          {activity.line.shortName}
        </span>
        <div className="min-w-0 flex-1">
          <p className="truncate text-xs font-semibold tracking-tight">
            {activity.destination}
          </p>
          <span className="relative block h-3.5 overflow-hidden text-[0.65rem] text-white/60">
            <AnimatePresence initial={false} mode="popLayout">
              <motion.span
                key={phase.stop}
                className="absolute inset-x-0 truncate"
                initial={reduceMotion ? false : { y: 14, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={reduceMotion ? {} : { y: -14, opacity: 0 }}
                transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
              >
                {phase.stop}
              </motion.span>
            </AnimatePresence>
          </span>
        </div>
        <div className="flex shrink-0 items-center gap-1">
          <span className="relative grid h-5 min-w-4 place-items-center overflow-hidden text-lg leading-none font-bold text-white tabular-nums">
            <AnimatePresence initial={false} mode="popLayout">
              <motion.span
                key={phase.minutes}
                className="absolute"
                initial={reduceMotion ? false : { y: -18, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={reduceMotion ? {} : { y: 18, opacity: 0 }}
                transition={{ duration: 0.42, ease: [0.22, 1, 0.36, 1] }}
              >
                {phase.minutes}
              </motion.span>
            </AnimatePresence>
          </span>
          <span className="text-[0.62rem] font-semibold tracking-wide text-white/55">
            {activity.unit}
          </span>
        </div>
      </div>
      <div
        className="mt-3 h-1 overflow-hidden rounded-full bg-white/15"
        aria-hidden="true"
      >
        <motion.div
          className="h-full rounded-full"
          style={{ backgroundColor: activity.line.color }}
          animate={{ width: `${phase.progress * 100}%` }}
          transition={
            reduceMotion
              ? { duration: 0 }
              : { type: "spring", bounce: 0, duration: 0.9 }
          }
        />
      </div>
    </div>
  );
}
